import Cocoa


@objc public protocol CommitType {
  var sha: String? { get }
  var oid: GTOID { get }
  var parentOIDs: [GTOID] { get }
  
  var message: String? { get }
  var commitDate: Date { get }
  var email: String? { get }
}

extension CommitType
{
  public var description: String
  { return "\(sha?.firstSix() ?? "-")" }
}


public func == (a: GTOID, b: GTOID) -> Bool
{
  return git_oid_cmp(a.git_oid(), b.git_oid()) == 0
}


public class XTCommit: NSObject, CommitType
{
  let gtCommit: GTCommit
  
  // These used to be lazy properties, but the Swift 3 compiler crashes on that.
  let cachedSHA: String?
  let cachedOID: GTOID
  let cachedParentOIDs: [GTOID]

  public var sha: String? { return cachedSHA }
  public var oid: GTOID { return cachedOID }

  public var parentOIDs: [GTOID] { return cachedParentOIDs }
  
  public var message: String?
  { return gtCommit.message }
  
  public var commitDate: Date
  { return gtCommit.commitDate }
  
  public var email: String?
  { return gtCommit.author?.email }

  init?(oid: GTOID, repository: XTRepository)
  {
    var gitCommit: OpaquePointer? = nil  // git_commit isn't imported
    let result = git_commit_lookup(&gitCommit,
                                   repository.gtRepo.git_repository(),
                                   oid.git_oid())
  
    guard result == 0,
          let commit = GTCommit(obj: gitCommit!, in: repository.gtRepo)
    else { return nil }
    
    self.gtCommit = commit
    self.cachedSHA = commit.sha
    self.cachedOID = commit.oid!
    self.cachedParentOIDs = XTCommit.calculateParentOIDs(gtCommit.git_commit())
  }
  
  convenience init?(sha: String, repository: XTRepository)
  {
    guard let oid = GTOID(sha: sha)
    else { return nil }
    
    self.init(oid: oid, repository: repository)
  }
  
  static func calculateParentOIDs(_ rawCommit: OpaquePointer) -> [GTOID]
  {
    var result = [GTOID]()
    
    for index in 0..<git_commit_parentcount(rawCommit) {
      let parentID = git_commit_parent_id(rawCommit, index)
      guard parentID != nil
      else { continue }
      
      result.append(GTOID(gitOid:parentID!))
    }
    return result
  }
  
  func calculateSHA() -> String?
  {
    return gtCommit.sha
  }
  
  func calculateOID() -> GTOID
  {
    return gtCommit.oid!
  }
}

public func == (a: XTCommit, b: XTCommit) -> Bool
{
  return git_oid_cmp(a.oid.git_oid(), b.oid.git_oid()) == 0
}