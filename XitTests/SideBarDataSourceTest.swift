import Foundation
import XCTest
@testable import Xit

class SidebarDataSourceTest: XTTest
{
  var outline = MockSidebarOutline()
  var model: SidebarDataModel!
  var sbds: SideBarDataSource!
  var runLoop: CFRunLoop?

  func groupItem(_ row: SidebarGroupIndex) -> SideBarGroupItem
  {
    return sbds.outlineView(outline, child: row.rawValue, ofItem: nil)
           as! SideBarGroupItem
  }

  @MainActor
  override func setUp()
  {
    super.setUp()
    
    model = SidebarDataModel(repository: repository)
    sbds = .init()
    sbds.model = model
    sbds.outline = outline
    outline.dataSource = sbds
  }

  /// Add a tag and make sure it gets loaded correctly
  @MainActor
  func testTags() throws
  {
    guard let headOID = repository.headSHA.flatMap({ repository.oid(forSHA: $0) })
    else {
      XCTFail("no head")
      return
    }
    try repository.createTag(name: "t1", targetOID: headOID, message: "msg")
    sbds.reload()
    waitForRepoQueue()
    
    let rowCount = sbds.outlineView(outline, numberOfChildrenOfItem: nil)
    
    XCTAssertEqual(rowCount, 6)
    
    let tagsGroup = groupItem(.tags)
    let tagCount = sbds.outlineView(outline, numberOfChildrenOfItem: tagsGroup)
    
    XCTAssertEqual(tagCount, 1)
    
    let tag = sbds.outlineView(outline, child: 0, ofItem: tagsGroup)
              as! SidebarItem
    let expandable = sbds.outlineView(outline, isItemExpandable: tag)
    
    XCTAssertNotNil(tag.selection?.oidToSelect)
    XCTAssertFalse(expandable)
  }
  
  /// Add a branch and make sure both branches are loaded correctly
  @MainActor
  func testBranches() throws
  {
    try execute(in: repository) {
      CreateBranch("b1")
    }
    sbds.reload()
    waitForRepoQueue()
    
    let branches = groupItem(.branches)
    let branchCount = sbds.outlineView(outline,
                                       numberOfChildrenOfItem: branches)
  
    XCTAssertEqual(branchCount, 2)
    for b in 0...1 {
      let branch = sbds.outlineView(outline, child: b, ofItem: branches)
                   as! SidebarItem
      let expandable = sbds.outlineView(outline, isItemExpandable: branch)
      
      XCTAssertNotNil(branch.selection?.oidToSelect)
      XCTAssertFalse(expandable)
    }
  }
  
  /// Create two stashes and check that they are listed
  @MainActor
  func testStashes() throws
  {
    try execute(in: repository) {
      Write("second text", to: .file1)
      SaveStash("s1")
      Write("third text", to: .file1)
      SaveStash("s2")
    }
    
    sbds.reload()
    waitForRepoQueue()
    
    let stashes = groupItem(.stashes)
    let stashCount = sbds.outlineView(outline, numberOfChildrenOfItem: stashes)
    
    XCTAssertEqual(stashCount, 2)
  }
  
  /// Check that a remote and its branches are displayed correctly
  @MainActor
  func testRemotes() throws
  {
    makeRemoteRepo()
    
    let remoteName = "origin"

    try execute(in: repository) {
      CheckOut(branch: "master")
      CreateBranch("b1")
    }
    try repository.addRemote(named: remoteName,
                             url: URL(fileURLWithPath: remoteRepoPath))
    
    let configArgs = ["config", "receive.denyCurrentBranch", "ignore"]
    
    _ = try remoteRepository.executeGit(args: configArgs, writes: false)
    try repository.push(remote: remoteName)
    
    sbds.reload()
    waitForRepoQueue()
    
    let remotes = groupItem(.remotes)
    let remoteCount = sbds.outlineView(outline, numberOfChildrenOfItem: remotes)
    
    XCTAssertEqual(remoteCount, 1)
    
    let remote = sbds.outlineView(outline, child: 0, ofItem: remotes)
    let branchCount = sbds.outlineView(outline, numberOfChildrenOfItem: remote)
    
    XCTAssertEqual(branchCount, 2)
    
    for index in 0...1 {
      let branch = sbds.outlineView(outline, child: index, ofItem: remote)
      let expandable = sbds.outlineView(outline, isItemExpandable: branch)
      
      XCTAssertFalse(expandable)
    }
  }
  
  @MainActor
  func testSubmodules() throws
  {
    let repoParentPath = (repoPath as NSString).deletingLastPathComponent
    let sub1Path = repoParentPath.appending(pathComponent: "repo1")
    let sub2Path = repoParentPath.appending(pathComponent: "repo2")
    
    for path in [sub1Path, sub2Path] {
      let subRepo = try XCTUnwrap(XTTest.createRepo(atPath: path))

      try execute(in: subRepo) {
        CommitFiles {
          Write("text", to: .file1)
        }
      }
    }
  
    try repository.addSubmodule(path: "sub1", url: "../repo1")
    try repository.addSubmodule(path: "sub2", url: "../repo2")
    XCTAssertEqual(repository.submodules().count, 2, "wrong submodule count")
    guard repository.submodules().count == 2
    else { return }
    
    sbds.reload()
    waitForRepoQueue()
    
    let subs = groupItem(.submodules)
    let subCount = sbds.outlineView(outline, numberOfChildrenOfItem: subs)
    
    XCTAssertEqual(subCount, 2)
    
    let subData = [("sub1", "../repo1"),
                   ("sub2", "../repo2")]
    
    for (index, data) in subData.enumerated() {
      let subItem = sbds.outlineView(outline, child: index, ofItem: subs)
                    as! SubmoduleSidebarItem
      
      XCTAssertEqual(subItem.submodule.name, data.0)
      XCTAssertEqual(subItem.submodule.url?.path, data.1)
    }
  }
}

extension SidebarItem
{
  var childrenTitles: [String] { return children.map { $0.title } }
}

class SidebarDSFakeRepoTest: XCTestCase
{
  @MainActor
  func testFilter()
  {
    let repo = FakeRepo()
    let controller = FakeRepoController(repository: repo)
    let model = SidebarDataModel(repository: repo)
    let sidebarDS = SideBarDataSource()
    let outline = NSOutlineView()

    _ = controller.repository // kill the warning
    model.reload()
    sidebarDS.model = model
    sidebarDS.outline = outline
    outline.dataSource = sidebarDS
    repo.controller?.waitForQueue()

    var filteredBranches = sidebarDS.displayItem(.branches)
                                    .children.map { $0.title }
    
    XCTAssertEqual(filteredBranches, ["branch1", "branch2"])
    
    sidebarDS.filterSet.filters = [SidebarNameFilter(string: "1")]
    sidebarDS.reload()
    repo.controller?.waitForQueue()

    filteredBranches = sidebarDS.displayItem(.branches)
                                .children.map { $0.title }
    
    XCTAssertEqual(filteredBranches, ["branch1"])
    
    let remotesItem = sidebarDS.displayItem(.remotes)
    let filteredRemotes = remotesItem.children.map { $0.title }
    
    XCTAssertEqual(filteredRemotes, ["origin1", "origin2"])
    
    let remoteBranches1 = remotesItem.children[0].childrenTitles
    let remoteBranches2 = remotesItem.children[1].childrenTitles
    
    XCTAssertEqual(remoteBranches1, ["branch1"])
    XCTAssertEqual(remoteBranches2, [])
  }
}

class MockSidebarOutline: NSOutlineView
{
  override func makeView(withIdentifier identifier: NSUserInterfaceItemIdentifier,
                         owner: Any?) -> NSView?
  {
    guard identifier == ◊"DataCell"
    else { return nil }
    
    let result = SidebarTableCellView(frame: NSRect(x: 0, y: 0,
                                                      width: 185, height: 20))
    let textField = NSTextField(frame: NSRect(x: 26, y: 3,
                                              width: 163, height: 17))
    let imageView = NSImageView(frame: NSRect(x: 5, y: 2,
                                              width: 16, height: 16))
    let statusImage = NSImageView(frame: NSRect(x: 171, y: 2,
                                                width: 16, height: 16))
    let statusButton = NSButton(frame: NSRect(x: 171, y: 2,
                                              width: 16, height: 16))
    let buttonContainer = NSView(frame: NSRect(x: 0, y: 0, width: 20, height: 16))
    let missingImage = NSImageView(frame: NSRect(x: 0, y: 0, width: 20, height: 16))
    let statusText = WorkspaceStatusIndicator()
    let prContanier = NSView(frame: NSRect(x: 0, y: 0, width: 20, height: 16))
    let pullRequestButton = NSPopUpButton(frame: NSRect(x: 0, y: 0,
                                                        width: 20, height: 16))
    let prStatusImage = NSImageView(frame: NSRect(x: 0, y: 0,
                                                  width: 20, height: 16))

    for view in [textField, imageView, statusImage, statusButton, statusText,
                 buttonContainer, missingImage, prContanier, pullRequestButton,
                 prStatusImage] {
      result.addSubview(view)
    }
    result.textField = textField
    result.imageView = imageView
    result.statusButton = statusButton
    result.statusText = statusText
    result.buttonContainer = buttonContainer
    result.missingImage = missingImage
    
    result.prContanier = prContanier
    result.pullRequestButton = pullRequestButton
    result.prStatusImage = prStatusImage
    
    return result
  }
}
