import Foundation

@MainActor
protocol ReselectingOutlineDelegate: AnyObject
{
  /// The user has clicked on the selected row.
  func outlineViewClickedSelectedRow(_ outline: NSOutlineView)
}

@objc(XTSideBarOutlineView)
final class SideBarOutlineView: ContextMenuOutlineView
{
  @IBOutlet public weak var controller: SidebarController!
  
  override func updateMenu(forItem item: Any)
  {
    switch item {
      case is RemoteBranchSidebarItem:
        menu = controller.remoteBranchContextMenu
      case is LocalBranchSidebarItem:
        menu = controller.branchContextMenu
      case is TagSidebarItem:
        menu = controller.tagContextMenu
      case is StashSidebarItem:
        menu = controller.stashContextMenu
      case is SubmoduleSidebarItem:
        menu = controller.submoduleContextMenu
      default:
        guard let groupItem = parent(forItem: item) as? SidebarItem
        else { break }
        
        if groupItem == controller.sidebarDS.model.rootItem(.remotes) {
          menu = controller.remoteContextMenu
        }
    }
  }
  
  override func mouseDown(with event: NSEvent)
  {
    let oldSelection = selectedRowIndexes
  
    super.mouseDown(with: event)
    
    let newSelection = selectedRowIndexes
    
    if oldSelection == newSelection,
       let xtDelegate = delegate as? ReselectingOutlineDelegate {
      xtDelegate.outlineViewClickedSelectedRow(self)
    }
  }
}
