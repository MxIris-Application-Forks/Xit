import Foundation

enum RepoError: Swift.Error
{
  case alreadyWriting
  case cherryPickInProgress
  case commitNotFound(String?)  // SHA
  case conflict  // List of conflicted files
  case detachedHead
  case duplicateName
  case fileNotFound(String)  // Path
  case gitError(Int32)
  case invalidName(String)
  case localConflict
  case mergeInProgress
  case notFound
  case patchMismatch
  case unexpected
  case workspaceDirty

  var message: UIString
  {
    switch self {
      case .alreadyWriting:
        return .alreadyWriting
      case .mergeInProgress:
        return .mergeInProgress
      case .cherryPickInProgress:
        return .cherryPickInProgress
      case .conflict:
        return .conflict
      case .duplicateName:
        return .duplicateName
      case .localConflict:
        return .localConflict
      case .detachedHead:
        return .detachedHead
      case .gitError(let code):
        return .gitError(code)
      case .invalidName(let name):
        return .invalidName(name)
      case .patchMismatch:
        return .patchMismatch
      case .commitNotFound(let sha):
        return .commitNotFound(sha?.firstSix())
      case .fileNotFound(let path):
        return .fileNotFound(path)
      case .notFound:
        return .notFound
      case .unexpected:
        return .unexpected
      case .workspaceDirty:
        return .workspaceDirty
    }
  }
  
  var localizedDescription: String { return message.rawValue }
  
  init(gitCode: git_error_code)
  {
    switch gitCode {
      case GIT_ECONFLICT, GIT_EMERGECONFLICT:
        self = .conflict
      case GIT_ELOCKED:
        self = .alreadyWriting
      case GIT_ENOTFOUND:
        self = .notFound
      case GIT_EUNMERGED:
        self = .mergeInProgress
      case GIT_EUNCOMMITTED, GIT_EINDEXDIRTY:
        self = .workspaceDirty
      default:
        self = .gitError(gitCode.rawValue)
    }
  }
  
  static func throwIfGitError(_ code: Int32) throws
  {
    guard code == 0
    else {
      throw RepoError(gitCode: git_error_code(code))
    }
  }
}
