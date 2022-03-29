import Foundation
import Cocoa

final class SidebarPRManager
{
  let refreshInterval: TimeInterval = 5 * .minutes
  
  let model: SidebarDataModel
  var pullRequestCache: PullRequestCache  // not `let` for testability
  var refreshTimer: Timer?

  init(model: SidebarDataModel)
  {
    self.model = model
    self.pullRequestCache = PullRequestCache(repository: model.repository!)
    
    pullRequestCache.add(client: self)
  }
  
  func scheduleCacheRefresh()
  {
    refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval,
                                        repeats: true) {
      [weak self] _ in
      self?.pullRequestCache.refresh()
    }
  }
  
  func stopCacheRefresh()
  {
    refreshTimer?.invalidate()
  }
  
  func remoteItem(for pullRequest: any PullRequest) -> RemoteBranchSidebarItem?
  {
    guard let sourceURL = pullRequest.sourceRepo,
          let remote = model.rootItem(.remotes).children.first(where: {
      ($0 as? RemoteSidebarItem)?.remote?.url == sourceURL
    })
    else { return nil }
    let sourceBranch = pullRequest.sourceBranch
                                  .droppingPrefix(RefPrefixes.heads)
    
    return remote.findChild {
      let name = ($0 as? RemoteBranchSidebarItem)?.branchObject()?.strippedName
      return name == sourceBranch
    } as? RemoteBranchSidebarItem
  }
  
  func pullRequest(for item: SidebarItem?) -> (any PullRequest)?
  {
    guard let branchItem = item as? BranchSidebarItem,
          let remote = branchItem.remote,
          let remoteURL = remote.url
    else { return nil }
    let branch = branchItem.branchObject()
    let branchName: String
    
    // Make sure we have the local version of the branch name
    switch branch {
      case let localBranch as LocalBranch:
        branchName = localBranch.name
      case let remoteBranch as RemoteBranch:
        branchName = remoteBranch.localBranchName
      default:
        return nil
    }
    
    return pullRequestCache.requests.first {
      $0.sourceBranch == branchName &&
      $0.matchRemote(url: remoteURL)
    }
  }
  
  func prStatusImage(status: PullRequestStatus,
                     approval: PullRequestApproval) -> NSImage?
  {
    let info: (String, NSColor)?
    
    switch status {
      case .open:
        switch approval {
          case .approved:
            info = ("checkmark.circle.fill", .systemGreen)
          case .needsWork:
            info = ("slash.circle.fill", .systemYellow)
          case .unreviewed:
            info = nil
        }
      case .merged:
        info = ("smallcircle.fill.circle.fill", .systemPurple)
      case .inactive:
        info = ("xmark.circle.fill", .systemRed)
      case .other:
        info = nil
    }
    
    return info.flatMap {
      NSImage(systemSymbolName: $0)?
        .withSymbolConfiguration(.init(pointSize: 10, weight: .regular))?
        .image(coloredWith: $1)
    }
  }
  
  func prStatusText(status: PullRequestStatus,
                    approval: PullRequestApproval) -> UIString?
  {
    switch status {
      case .open:
        switch approval {
          case .approved:
            return .approved
          case .needsWork:
            return .needsWork
          case .unreviewed:
            return nil
        }
      case .merged:
        return .merged
      case .inactive:
        return .closed
      case .other:
        return nil
    }
  }
  
  func updatePullRequestMenu(popup: NSPopUpButton, pullRequest: any PullRequest)
  {
    let actions = pullRequest.availableActions

    for item in popup.itemArray {
      switch item.action {
        case #selector(SidebarTableCellView.viewPRWebPage(_:)):
          item.isHidden = pullRequest.webURL == nil
        case #selector(SidebarTableCellView.approvePR(_:)):
          item.isHidden = !actions.contains(.approve)
        case #selector(SidebarTableCellView.unapprovePR(_:)):
          item.isHidden = !actions.contains(.unapprove)
        case #selector(SidebarTableCellView.prNeedsWork(_:)):
          item.isHidden = !actions.contains(.needsWork)
        default:
          break
      }
    }
  }
  
  func updatePullRequestButton(item: SidebarItem, view: SidebarTableCellView)
  {
    guard let pullRequest = pullRequest(for: item)
    else {
      view.prContanier.isHidden = true
      return
    }
    
    view.prContanier.isHidden = false
    view.prStatusImage.image = prStatusImage(status: pullRequest.status,
                                             approval: pullRequest.userApproval)
    if let text = prStatusText(status: pullRequest.status,
                               approval: pullRequest.userApproval) {
      view.pullRequestButton.toolTip =
          "(\(text.rawValue)) \(pullRequest.displayName)"
    }
    else {
      view.pullRequestButton.toolTip = pullRequest.displayName
    }
    updatePullRequestMenu(popup: view.pullRequestButton,
                          pullRequest: pullRequest)
  }
}

extension SidebarPRManager: PullRequestClient
{
  func pullRequestUpdated(branch: String, requests: [any PullRequest])
  {
    DispatchQueue.main.async {
      for request in requests {
        guard let item = self.remoteItem(for: request)
        else { continue }
        
        self.model.outline?.reloadItem(item)
      }
    }
  }
}

extension SidebarPRManager: PullRequestActionDelegate
{
  func viewPRWebPage(item: SidebarItem)
  {
    guard let pullRequest = pullRequest(for: item),
          let url = pullRequest.webURL
    else { return }
    
    NSWorkspace.shared.open(url)
  }

  private func tryPRTask(item: SidebarItem,
                         approval: PullRequestApproval,
                         block: @escaping (PullRequest) async throws -> Void)
  {
    guard let pullRequest = pullRequest(for: item)
    else { return }

    Task.detached {
      do {
        try await block(pullRequest)
        self.pullRequestCache.update(pullRequestID: pullRequest.id,
                                     approval: approval)
      }
      catch let error {
        self.prActionFailed(item: item, error: error)
      }
    }
  }

  func approvePR(item: SidebarItem)
  {
    tryPRTask(item: item, approval: .approved) {
      try await $0.service.approve(request: $0)
    }
  }
  
  func unapprovePR(item: SidebarItem)
  {
    tryPRTask(item: item, approval: .unreviewed) {
      try await $0.service.unapprove(request: $0)
    }
  }
  
  func prNeedsWork(item: SidebarItem)
  {
    tryPRTask(item: item, approval: .needsWork) {
      try await $0.service.needsWork(request: $0)
    }
  }
  
  private func prActionFailed(item: SidebarItem, error: Error)
  {
    guard let window = model.outline?.window
    else { return }
    let alert = NSAlert()
    
    alert.messageString = .prActionFailed
    alert.informativeText = (error as CustomStringConvertible).description
    alert.beginSheetModal(for: window)
  }
}
