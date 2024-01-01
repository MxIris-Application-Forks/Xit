import Foundation

extension AXID
{
  public enum Button
  {
    static let accept = AXID("acceptButton")
    static let cancel = AXID("cancelButton")
  }

  public enum Clean
  {
    static let window = AXID("cleanWindow")

    public enum Text
    {
      static let total = AXID("totalText")
      static let selected = AXID("selectedText")
    }

    public enum Controls
    {
      static let directories = AXID("directoriesCheck")
      static let fileMode = AXID("fileModePicker")
      static let folderMode = AXID("folderModePicker")
      static let filterType = AXID("filterType")
      static let filterField = AXID("filterField")
      static let fileList = AXID("fileList")
    }

    public enum Button
    {
      static let refresh = AXID("refreshButton")
      static let cancel = AXID("cancelButton")
      static let cleanSelected = AXID("cleanSelectedButton")
      static let cleanAll = AXID("cleanAllButton")
    }

    public enum List
    {
      static let fileName = AXID("fileName")
    }
  }

  enum FetchSheet
  {
    static let remotePopup = AXID("remote")
    static let tagsCheck = AXID("downloadTags")
    static let pruneCheck = AXID("pruneBranches")
  }

  public enum Search
  {
    static let typePopup = AXID("searchType")
    static let field = AXID("searchField")
    static let up = AXID("searchUp")
    static let down = AXID("searchDown")
  }

  public enum FileList
  {
    public enum Commit
    {
      static let group = AXID("commitFiles")
      static let list = AXID("commitList")
    }

    public enum Staged
    {
      static let group = AXID("staged")
      static let list = AXID("stagedList")
    }

    public enum Workspace
    {
      static let group = AXID("workspace")
      static let list = AXID("workspaceList")
    }

    static let stagedGroup = AXID("staged")
    static let workspaceGroup = AXID("workspace")
    static let viewSelector = AXID("viewSelector")
  }

  enum Menu
  {
    static let branch = AXID("branchPopup")
    static let remoteBranch = AXID("remoteBranchPopup")
    static let tag = AXID("tagPopup")
  }

  enum BranchPopup
  {
    static let checkOut = AXID("checkOutBranch")
    static let rename = AXID("renameBranch")
    static let merge = AXID("mergeBranch")
    static let delete = AXID("deleteBranch")
  }
  
  enum RemoteBranchPopup
  {
    static let createTracking = AXID("createTrackingBranch")
  }

  enum StashPopup
  {
    static let pop = AXID("popStash")
    static let apply = AXID("applyStash")
    static let drop = AXID("dropStash")
  }

  enum TagPopup
  {
    static let delete = AXID("deleteTag")
  }
  
  enum PopupMenu
  {
    static let pull = AXID("pullPopup")
    static let push = AXID("pushPopup")
    static let fetch = AXID("fetchPopup")
  }

  enum Preferences
  {
    static let window = AXID("Preferences")

    enum Controls
    {
      static let collapseHistory = AXID("collapseHistory")
      static let deemphasize = AXID("deemphasize")
      static let resetAmend = AXID("resetAmend")
      static let tabStatus = AXID("tabStatus")
    }

    enum Toolbar
    {
      static let general = AXID("General")
    }
  }

  enum Sidebar
  {
    static let add = AXID("sidebarAdd")
    static let currentBranch = AXID("currentBranch")
    static let filter = AXID("sidebarFilter")
    static let list = AXID("sidebar")
    static let trackingStatus = AXID("trackingStatus")
    static let workspaceStatus = AXID("workspaceStatus")
  }
  
  enum CreateTracking
  {
    static let window = AXID("checkOutBranch")
    static let prompt = AXID("prompt")
    static let branchName = AXID("branchName")
    static let checkOut = AXID("checkOut")
    static let errorMessage = AXID("error")
  }
}
