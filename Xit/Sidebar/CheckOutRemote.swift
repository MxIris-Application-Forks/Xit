import Cocoa

final class CheckOutRemoteOperationController: OperationController
{
  let remoteBranch: String
  var sheetController: CheckOutRemoteWindowController!
  
  init(windowController: XTWindowController, branch: String)
  {
    self.remoteBranch = branch
    
    super.init(windowController: windowController)

    self.sheetController =
        CheckOutRemoteWindowController(repo: windowController.repository,
                                       operation: self)
  }
  
  override func start() throws
  {
    sheetController.setRemoteBranchName(remoteBranch)
    windowController!.window?.beginSheet(sheetController.window!) {
      (response) in
      if response == .OK {
        self.performOperation(newBranchName: self.sheetController.branchName,
                              shouldCheckOut: self.sheetController.checkOutBranch)
      }
    }
  }
  
  func performOperation(newBranchName: String, shouldCheckOut: Bool)
  {
    guard let repository = windowController?.repository
    else { return }
    
    do {
      let fullTarget = RefPrefixes.remotes + remoteBranch
      
      if let branch = try repository.createBranch(named: newBranchName,
                                                  target: fullTarget) {
        branch.trackingBranchName = remoteBranch
        if shouldCheckOut {
          try repository.checkOut(branch: newBranchName)
        }
      }
    }
    catch let error as RepoError {
      windowController?.showErrorMessage(error: error)
    }
    catch {
      windowController?.showErrorMessage(error: .unexpected)
    }
  }
}

class CheckOutRemoteWindowController: NSWindowController
{
  @IBOutlet weak var promptLabel: NSTextField!
  @IBOutlet weak var errorLabel: NSTextField!
  @IBOutlet weak var nameField: NSTextField!
  @IBOutlet weak var createButton: NSButton!
  @IBOutlet weak var checkOutCheckbox: NSButton!
  
  @ControlStringValue var branchName: String
  @ControlBoolValue var checkOutBranch: Bool
  
  private let repo: any Branching
  private unowned let operation: CheckOutRemoteOperationController
  
  override var windowNibName: NSNib.Name? { "CheckOutRemote" }
  
  init(repo: any Branching, operation: CheckOutRemoteOperationController)
  {
    self.repo = repo
    self.operation = operation
    super.init(window: nil)
  }
  
  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func windowDidLoad()
  {
    super.windowDidLoad()
    
    $branchName = nameField
    $checkOutBranch = checkOutCheckbox
  }
  
  func setRemoteBranchName(_ remoteBranch: String)
  {
    loadWindow()
    promptLabel.uiStringValue = .createTracking(remoteBranch)
    nameField.stringValue = remoteBranch.deletingFirstPathComponent
    updateCreateButton()
  }
  
  func endSheet(_ result: NSApplication.ModalResponse)
  {
    guard let window = self.window,
          let parent = window.sheetParent
    else { return }
    
    parent.endSheet(window, returnCode: result)
    operation.ended()
  }
  
  func updateCreateButton()
  {
    let branchName = nameField.stringValue
    let refName = LocalBranchRefName(branchName)
    var errorText = UIString.empty
    
    if let refName {
      if repo.localBranch(named: refName) != nil {
        errorText = .branchNameExists
      }
    }
    else {
      errorText = .branchNameInvalid
    }

    errorLabel.uiStringValue = errorText
    createButton.isEnabled = errorText.rawValue.isEmpty
  }

  @IBAction
  func cancelSheet(_ sender: Any)
  {
    endSheet(.cancel)
  }
  
  @IBAction
  func create(_ sender: Any)
  {
    endSheet(.OK)
  }
}

extension CheckOutRemoteWindowController: NSControlTextEditingDelegate
{
  func controlTextDidChange(_ obj: Notification)
  {
    updateCreateButton()
  }
}
