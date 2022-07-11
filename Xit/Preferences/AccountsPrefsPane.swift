import SwiftUI

struct ServiceLabel: View
{
  let type: AccountType
  @Environment(\.lineSpacing) var lineSpacing: CGFloat

  var body: some View
  {
    // Using `Label` doesn't work in menus
    HStack {
      Image(type.imageName)
        .renderingMode(.template)
        .imageScale(.large)
        .frame(width: 18)
      Text(type.displayName)
    }
  }

  init(_ type: AccountType)
  {
    self.type = type
  }
}

fileprivate let bottomBarHeight: CGFloat = 21

struct AccountsPrefsPane: View
{
  let services: Services
  @ObservedObject var accountsManager: AccountsManager

  @State var selectedAccountID: UUID?
  @State var newAccountInfo: AccountInfo?
  @State var editAccountInfo: AccountInfo?

  @State var showAlert: Bool = false
  @State var showDeleteConfirmation: Bool = false
  @State var passwordError: PasswordError?

  var selectedAccount: Account?
  {
    selectedAccountID.flatMap {
      (id) in
      accountsManager.accounts.first { $0.id == id }
    }
  }

  func squareImage(_ systemName: String,
                   size: CGFloat = bottomBarHeight) -> some View
  {
    Image(systemName: systemName)
      .frame(width: size, height: size)
      .contentShape(Rectangle())
  }

  var body: some View
  {
    VStack(spacing: -1) {
      Table(accountsManager.accounts, selection: $selectedAccountID) {
        TableColumn("Service", content: { ServiceLabel($0.type) })
            .width(min: 40, ideal: 80)
        TableColumn("User name", value: \.user)
        TableColumn("Location", value: \.location.absoluteString)
            .width(min: 40, ideal: 150)
        TableColumn("Status") {
          AccountStatusCell.for(service: services.service(for: $0))
        }.width(47)
      }.tableStyle(.bordered)
      HStack {
        HStack(spacing: 0) {
          Button(action: addNewAccount, label: { squareImage("plus") })
            .help("Add new account")
            .frame(minWidth: bottomBarHeight, maxHeight: .infinity)
            .sheet(item: $newAccountInfo, content: newAccountSheet(_:))
          Divider()
          Button(action: { showDeleteConfirmation = true },
                 label: { squareImage("minus") })
            .help("Delete account")
            .disabled(selectedAccountID == nil)
            .confirmationDialog(.confirmDeleteAccount,
                                isPresented: $showDeleteConfirmation) {
              Button(.delete, role: .destructive, action: deleteAccount)
              Button(.cancel, role: .cancel, action: {})
            }
          Divider()
        }.buttonStyle(.plain)
        Spacer()
        HStack {
          Button(action: editAccount, label: { squareImage("pencil") })
            .sheet(item: $editAccountInfo, content: editAccountSheet(_:))
            .help("Edit account")
          Button(action: refreshAccount,
                 label: { squareImage("arrow.clockwise.circle.fill") })
            .padding([.trailing], 4)
            .help("Refresh account status")
        }.buttonStyle(.plain)
          .disabled(selectedAccountID == nil)
      }.background(.tertiary)
        .frame(height: bottomBarHeight)
        .border(.tertiary)
    }.alert(isPresented: $showAlert, error: passwordError) {
      Button(.ok, action: { showAlert = false })
    }
  }

  func newAccountSheet(_ info: AccountInfo) -> some View
  {
    var info = info
    let binding = Binding<AccountInfo>(get: { info }, set: { info = $0 })

    return accountInfoSheet(for: binding, title: "Create",
                            action: { addAccount(from: info) },
                            cancel: { newAccountInfo = nil })
  }

  func editAccountSheet(_ info: AccountInfo) -> some View
  {
    var info = info
    let binding = Binding<AccountInfo>(get: { info }, set: { info = $0 })

    return accountInfoSheet(for: binding, title: "Save",
                            action: { modifyAccount(with: info) },
                            cancel: { editAccountInfo = nil })
  }

  func accountInfoSheet(for binding: Binding<AccountInfo>,
                        title: String,
                        action: @escaping () -> Void,
                        cancel: @escaping () -> Void) -> some View
  {
    VStack {
      EditAccountPanel(model: binding.wrappedValue)
        .onSubmit(action)
      DialogButtonRow(validator: binding.wrappedValue, buttons: [
        (.cancel, cancel),
        (.accept(title), action),
      ])
    }.padding()
  }

  func addNewAccount()
  {
    newAccountInfo = AccountInfo() // trigger the sheet
  }

  func addAccount(from info: AccountInfo)
  {
    do {
      let account = Account(type: info.serviceType,
                            user: info.userName,
                            location: .init(string: info.location)!,
                            id: info.id)

      try accountsManager.add(account, password: info.password)
    }
    catch let error as PasswordError {
      self.passwordError = error
      showAlert = true
    }
    catch {}
  }

  func modifyAccount(with info: AccountInfo)
  {
    editAccountInfo = nil

    guard let account = accountsManager.accounts
                                       .first(where: { $0.id == info.id }),
          let url = URL(string: info.location)
    else { return }

    do {
      try accountsManager.modify(oldAccount: account,
                                 newAccount: .init(type: info.serviceType,
                                                   user: info.userName,
                                                   location: url,
                                                   id: account.id),
                                 newPassword: info.password)
    }
    catch let error as PasswordError {
      passwordError = error
    }
    catch {
      assertionFailure("unexpected error")
    }
  }

  func deleteAccount()
  {
    guard let account = selectedAccount
    else { return }

    accountsManager.delete(account: account)
  }

  func editAccount()
  {
    guard let account = selectedAccount
    else { return }
    let password = accountsManager.passwordStorage.find(account: account) ?? ""

    editAccountInfo = AccountInfo(with: account, password: password)
  }

  func refreshAccount()
  {
    guard let account = selectedAccount
    else { return }

    services.service(for: account)?.attemptAuthentication()
  }
}

struct AccountsPrefsPane_Previews: PreviewProvider
{
  static let manager: AccountsManager = {
    let accounts: [Account] = [
      .init(type: .gitHub, user: "This guy",
            location: .init(string:"https://github.com")!, id: .init()),
      .init(type: .teamCity, user: "Person",
            location: .init(string:"https://teamcity.com")!, id: .init()),
      .init(type: .gitLab, user: "Henry",
            location: .init(string:"https://gitlab.com")!, id: .init()),
      .init(type: .bitbucketServer, user: "Hank",
            location: .init(string:"https://bitbucket.com")!, id: .init()),
    ]
    let defaults = UserDefaults.testing
    let manager = AccountsManager(defaults: defaults,
                                  passwordStorage: MemoryPasswordStorage())

    defaults.accounts = accounts
    manager.readAccounts()
    return manager
  }()
  static let services: Services = {
    let result = Services(passwordStorage: MemoryPasswordStorage())
    result.serviceMakers[.teamCity] = MockAuthService.maker
    return result
  }()

  static var previews: some View
  {
    AccountsPrefsPane(services: services, accountsManager: manager)
      .padding().frame(height: 300.0)
  }
}
