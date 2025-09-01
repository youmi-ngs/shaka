//
//  ReportView.swift
//  Shaka
//
//  Created by Assistant on 2025/08/17.
//

import SwiftUI

struct ReportView: View {
    @StateObject private var viewModel = ReportViewModel()
    @Environment(\.dismiss) var dismiss
    
    let targetId: String
    let targetType: ReportType
    let targetUserId: String
    let targetTitle: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Why are you reporting this?")) {
                    Picker("Reason", selection: $viewModel.selectedReason) {
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            VStack(alignment: .leading) {
                                Text(reason.rawValue)
                                    .font(.headline)
                                Text(reason.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(reason)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 150)
                }
                
                Section(header: Text("Additional Details (Optional)")) {
                    TextEditor(text: $viewModel.additionalDetails)
                        .frame(minHeight: 100)
                        .overlay(
                            Group {
                                if viewModel.additionalDetails.isEmpty {
                                    Text("Provide any additional context that might help us review this report...")
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section {
                    Text("Reports are reviewed by our moderation team. False reports may result in action against your account.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        viewModel.submitReport(
                            targetId: targetId,
                            targetType: targetType,
                            targetUserId: targetUserId,
                            targetTitle: targetTitle
                        )
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isSubmitting)
                }
            }
            .disabled(viewModel.isSubmitting)
            .overlay(
                Group {
                    if viewModel.isSubmitting {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .overlay(
                                ProgressView("Submitting...")
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                    .cornerRadius(10)
                            )
                    }
                }
            )
        }
        .alert("Report Submitted", isPresented: $viewModel.showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Thank you for helping keep our community safe. We'll review your report shortly.")
        }
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

#Preview {
    ReportView(
        targetId: "sample-id",
        targetType: .work,
        targetUserId: "sample-user-id",
        targetTitle: "Sample Post"
    )
}