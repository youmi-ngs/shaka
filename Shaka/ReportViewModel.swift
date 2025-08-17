//
//  ReportViewModel.swift
//  Shaka
//
//  Created by Assistant on 2025/01/17.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

enum ReportReason: String, CaseIterable {
    case spam = "Spam"
    case inappropriate = "Inappropriate Content"
    case harassment = "Harassment or Bullying"
    case violence = "Violence or Dangerous Content"
    case misinformation = "Misinformation"
    case copyright = "Copyright Violation"
    case other = "Other"
    
    var description: String {
        switch self {
        case .spam:
            return "Unwanted commercial content or spam"
        case .inappropriate:
            return "Sexually explicit or adult content"
        case .harassment:
            return "Bullying, harassment, or hate speech"
        case .violence:
            return "Violence, self-harm, or dangerous activities"
        case .misinformation:
            return "False or misleading information"
        case .copyright:
            return "Copyright or intellectual property violation"
        case .other:
            return "Other reason not listed"
        }
    }
}

enum ReportType {
    case work
    case question
    case comment
    case user
}

class ReportViewModel: ObservableObject {
    @Published var selectedReason: ReportReason = .spam
    @Published var additionalDetails: String = ""
    @Published var isSubmitting = false
    @Published var showSuccessAlert = false
    @Published var showErrorAlert = false
    @Published var errorMessage = ""
    
    private var db = Firestore.firestore()
    
    func submitReport(
        targetId: String,
        targetType: ReportType,
        targetUserId: String,
        targetTitle: String? = nil
    ) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to report content"
            showErrorAlert = true
            return
        }
        
        isSubmitting = true
        
        let reportData: [String: Any] = [
            "reporterId": currentUserId,
            "targetId": targetId,
            "targetType": targetTypeString(targetType),
            "targetUserId": targetUserId,
            "targetTitle": targetTitle ?? "",
            "reason": selectedReason.rawValue,
            "reasonDescription": selectedReason.description,
            "additionalDetails": additionalDetails,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "pending",
            "reviewed": false
        ]
        
        db.collection("reports").addDocument(data: reportData) { [weak self] error in
            DispatchQueue.main.async {
                self?.isSubmitting = false
                
                if let error = error {
                    self?.errorMessage = "Failed to submit report: \(error.localizedDescription)"
                    self?.showErrorAlert = true
                } else {
                    self?.showSuccessAlert = true
                    self?.resetForm()
                }
            }
        }
    }
    
    private func targetTypeString(_ type: ReportType) -> String {
        switch type {
        case .work:
            return "work"
        case .question:
            return "question"
        case .comment:
            return "comment"
        case .user:
            return "user"
        }
    }
    
    private func resetForm() {
        selectedReason = .spam
        additionalDetails = ""
    }
}