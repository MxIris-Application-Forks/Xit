import Foundation

/// Fake SHA value for selecting staging view.
let XTStagingSHA = ""

/// Staged and unstaged workspace changes
class StagingSelection: StagedUnstagedSelection
{
  unowned var repository: any FileChangesRepo
  var shaToSelect: String? { XTStagingSHA }
  var canCommit: Bool { true }
  var fileList: any FileListModel { indexFileList }
  var unstagedFileList: any FileListModel { workspaceFileList }
  
  // Initialization requires a reference to self
  fileprivate(set) var indexFileList: IndexFileList!
  fileprivate(set) var workspaceFileList: WorkspaceFileList!
  
  init(repository: any FileChangesRepo)
  {
    self.repository = repository
    
    setFileLists()
  }
  
  func setFileLists()
  {
    indexFileList = IndexFileList(selection: self)
    workspaceFileList = WorkspaceFileList(selection: self)
  }
}

/// Staging selection with Amend turned on
final class AmendingSelection: StagingSelection
{
  override func setFileLists()
  {
    indexFileList = AmendingIndexFileList(selection: self)
    workspaceFileList = WorkspaceFileList(selection: self)
  }
}
