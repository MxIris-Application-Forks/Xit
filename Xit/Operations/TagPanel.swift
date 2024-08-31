import SwiftUI
import Combine

struct TagPanel: DataModelView
{
  final class Model: ObservableObject, Validating
  {
    let commitMessage: String
    let signature: Signature
    @Published var tagName: String
    @Published var tagType: TagType
    @Published var message: String

    @Published var isValid: Bool = true
    private var validCancellable: AnyCancellable?

    init(commitMessage: String,
         signature: Signature,
         tagName: String = "",
         tagType: TagType = .annotated,
         message: String = "")
    {
      self.commitMessage = commitMessage
      self.signature = signature
      self.tagName = tagName
      self.tagType = tagType
      self.message = message
      validCancellable = $tagName.sink {
        self.isValid = Self.validate($0)
      }
    }

    private static func validate(_ tagName: String) -> Bool
    {
      !tagName.isEmpty && GitReference.isValidName("refs/tags/\(tagName)")
    }
  }

  @ObservedObject var model: Model

  var body: some View
  {
    Form {
      TextField(.target.colon, text: .constant(model.commitMessage))
          .textFieldStyle(.plain)
          .focusable(false)
          .selectionDisabled()
          .allowsHitTesting(false)
      TextField(.tagName.colon, text: $model.tagName)
      Picker(.tagType.colon, selection: $model.tagType.animation()) {
        Text(.lightweight).tag(TagType.lightweight)
        Text(.annotated).tag(TagType.annotated)
      }.pickerStyle(.radioGroup)
      if model.tagType == .annotated {
        LabeledContent(.annotation.colon) {
          VStack(alignment: .leading) {
            Text("\(model.signature.name ?? "") <\(model.signature.email ?? "")>")
            TextEditor(text: $model.message)
                .font(.body.monospaced())
                // Allowing variable height causes layout issues in the sheet
                // at runtime.
                .frame(height: 67)
                .border(.tertiary)
          }
        }
          .disabled(model.tagType == .lightweight)
          .foregroundColor(model.tagType == .annotated ? .primary : .secondary)
      }
    }.frame(minWidth: 350)
  }
}

struct NewTagDialog: SheetDialog
{
  typealias ContentView = TagPanel

  let commitMessage: String
  let signature: Signature

  var acceptButtonTitle: UIString { .create }

  func createModel() -> ContentView.Model?
  {
    .init(commitMessage: commitMessage, signature: signature)
  }
}

struct TagPanel_Previews: PreviewProvider
{
  static var model: TagPanel.Model =
    .init(commitMessage: "Commit message",
          signature: .init(name: "Name", email: "email",
                           when: .now))

  static var previews: some View
  {
    VStack {
      TagPanel(model: model)
      DialogButtonRow(validator: model, buttons: [
        (.cancel, {}),
        (.accept("Create"), {}),
      ])
    }.padding()
  }
}
