//
//  ReusablePostFormView.swift
//  Shaka
//
//  Created by Youmi Nagase on 2025/05/05.
//

import SwiftUI

struct ReusablePostFormView<ImageContent: View, AdditionalContent: View>: View {
    @Binding var title: String
    @Binding var bodyText: String
    @Binding var isSubmitting: Bool
    
    let titlePlaceholder: String
    let bodyPlaceholder: String
    let bodyLabel: String
    let submitButtonText: String
    let submitButtonColor: Color
    let errorMessage: String?
    let canSubmit: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void
    
    @ViewBuilder let imageSection: () -> ImageContent
    @ViewBuilder let additionalContent: () -> AdditionalContent
    
    init(
        title: Binding<String>,
        bodyText: Binding<String>,
        isSubmitting: Binding<Bool> = .constant(false),
        titlePlaceholder: String = "Enter title",
        bodyPlaceholder: String = "Enter description",
        bodyLabel: String = "Description",
        submitButtonText: String = "Submit",
        submitButtonColor: Color = .blue,
        errorMessage: String? = nil,
        canSubmit: Bool,
        onSubmit: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        @ViewBuilder imageSection: @escaping () -> ImageContent = { EmptyView() },
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() }
    ) {
        self._title = title
        self._bodyText = bodyText
        self._isSubmitting = isSubmitting
        self.titlePlaceholder = titlePlaceholder
        self.bodyPlaceholder = bodyPlaceholder
        self.bodyLabel = bodyLabel
        self.submitButtonText = submitButtonText
        self.submitButtonColor = submitButtonColor
        self.errorMessage = errorMessage
        self.canSubmit = canSubmit
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        self.imageSection = imageSection
        self.additionalContent = additionalContent
    }
    
    var body: some View {
        Form {
            // Image section (optional)
            imageSection()
            
            // Title section
            Section(header: HStack {
                Text("Title")
                Text("(Required)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }) {
                TextField(titlePlaceholder, text: $title)
            }
            
            // Body/Description section
            Section(header: HStack {
                Text(bodyLabel)
                Text("(Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }) {
                TextEditor(text: $bodyText)
                    .frame(minHeight: 100)
            }
            
            // Additional content section
            additionalContent()
            
            // Error message section
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            // Submit button section
            Section {
                Button(action: onSubmit) {
                    if isSubmitting {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                            Text("Processing...")
                                .padding(.leading, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    } else {
                        Text(submitButtonText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSubmit ? submitButtonColor : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(!canSubmit || isSubmitting)
            }
        }
        .navigationBarItems(trailing: Button("Cancel", action: onCancel))
    }
}

// Extension for cases without image content
extension ReusablePostFormView where ImageContent == EmptyView, AdditionalContent == EmptyView {
    init(
        title: Binding<String>,
        bodyText: Binding<String>,
        isSubmitting: Binding<Bool> = .constant(false),
        titlePlaceholder: String = "Enter title",
        bodyPlaceholder: String = "Enter description",
        bodyLabel: String = "Description",
        submitButtonText: String = "Submit",
        submitButtonColor: Color = .blue,
        errorMessage: String? = nil,
        canSubmit: Bool,
        onSubmit: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.init(
            title: title,
            bodyText: bodyText,
            isSubmitting: isSubmitting,
            titlePlaceholder: titlePlaceholder,
            bodyPlaceholder: bodyPlaceholder,
            bodyLabel: bodyLabel,
            submitButtonText: submitButtonText,
            submitButtonColor: submitButtonColor,
            errorMessage: errorMessage,
            canSubmit: canSubmit,
            onSubmit: onSubmit,
            onCancel: onCancel,
            imageSection: { EmptyView() },
            additionalContent: { EmptyView() }
        )
    }
}

#Preview("With Image") {
    NavigationView {
        ReusablePostFormView(
            title: .constant(""),
            bodyText: .constant(""),
            canSubmit: true,
            onSubmit: {},
            onCancel: {}
        ) {
            Section(header: Text("Photo")) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(Text("Image Picker Here"))
            }
        }
        .navigationTitle("Post Work")
    }
}

#Preview("Without Image") {
    NavigationView {
        ReusablePostFormView(
            title: .constant("Test Title"),
            bodyText: .constant("Test Body"),
            bodyLabel: "Question Details",
            submitButtonColor: .purple,
            canSubmit: true,
            onSubmit: {},
            onCancel: {}
        )
        .navigationTitle("Ask a Question")
    }
}