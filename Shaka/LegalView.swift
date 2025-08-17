//
//  LegalView.swift
//  Shaka
//
//  Created by Assistant on 2025/08/18.
//

import SwiftUI

struct LegalView: View {
    let type: LegalType
    @Environment(\.dismiss) var dismiss
    
    enum LegalType {
        case terms
        case privacy
        
        var title: String {
            switch self {
            case .terms:
                return "Terms of Service"
            case .privacy:
                return "Privacy Policy"
            }
        }
        
        var content: String {
            switch self {
            case .terms:
                return LegalContent.termsOfService
            case .privacy:
                return LegalContent.privacyPolicy
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(type.content)
                    .font(.body)
                    .padding()
                    .textSelection(.enabled)
            }
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LegalContent {
    static let termsOfService = """
    Terms of Service
    Last Updated: August 18, 2025
    
    1. OVERVIEW
    
    Shaka is a community platform for photography enthusiasts. Users can share photographic works, post technical questions, and interact with other users.
    
    2. TERMS OF USE
    
    Account Registration
    • Valid account creation is required to use this service
    • Registration with false information is prohibited
    • Users are responsible for managing their accounts
    
    Age Restrictions
    • Users under 13 years old cannot use this service
    • Minors must obtain parental consent before use
    
    3. PROHIBITED ACTIVITIES
    
    Content Restrictions
    • Content that infringes on others' rights (copyright, portrait rights, etc.)
    • Obscene, violent, or discriminatory content
    • False or misleading information
    • Spam or commercial advertising (except where permitted)
    
    Behavioral Restrictions
    • Harassment, threats, or bullying of other users
    • Unauthorized access or system attacks
    • Misuse of multiple accounts
    • Activities that interfere with service operations
    
    4. CONTENT HANDLING
    
    Content Rights
    • Copyright of posted content belongs to the poster
    • By posting, you grant necessary licenses for display and distribution within the service
    
    Content Removal
    • Content violating these terms may be removed without notice
    • Content reported as inappropriate will be subject to review
    
    5. PRIVACY
    
    Personal information is handled according to our separate Privacy Policy.
    
    6. DISCLAIMER
    
    Service Provision
    • This service is provided "as is"
    • Service may be interrupted or terminated without prior notice
    
    Limitation of Liability
    • We are not responsible for disputes between users
    • We are not liable for damages arising from use of this service, except in cases of intent or gross negligence
    
    7. CHANGES TO TERMS
    
    These terms may be changed without notice. Important changes will be notified within the app.
    
    8. GOVERNING LAW
    
    These terms are governed by Japanese law, with the Tokyo District Court as the exclusive court of first instance.
    
    9. CONTACT
    
    For inquiries about these terms, please use the in-app reporting function.
    
    © 2025 Shaka. All rights reserved.
    """
    
    static let privacyPolicy = """
    Privacy Policy
    Last Updated: August 18, 2025
    
    1. INTRODUCTION
    
    Shaka values user privacy and strives to protect personal information. This Privacy Policy explains what information we collect and how we use and protect it.
    
    2. INFORMATION WE COLLECT
    
    Information You Provide
    • Account Information: Display name, profile photo
    • Posted Content: Photos, text, tags
    • Location Information: Optionally shared shooting locations
    
    Automatically Collected Information
    • Usage Information: App usage patterns, feature usage frequency
    • Device Information: Device type, OS, app version
    • Authentication Information: User ID via Firebase Authentication
    
    Apple ID Sign-In
    • When signing in with Apple ID, we only receive the identifier provided by Apple
    • Email sharing is optional (private relay available)
    
    3. HOW WE USE INFORMATION
    
    Service Provision
    • Account creation and management
    • Content posting and sharing
    • User interaction features
    
    Service Improvement
    • Usage analysis
    • New feature development
    • User experience enhancement
    
    Safety and Security
    • Fraud prevention
    • Terms violation detection
    • Report function operation
    
    Notifications
    • In-app notifications (likes, comments, follows)
    • Important announcements (optional)
    
    4. INFORMATION SHARING
    
    With Other Users
    • Profile information and posts are public to other users
    • Bookmarks and private information are only visible to you
    
    With Third Parties
    We do not provide personal information to third parties except:
    • Legal disclosure requirements
    • With user consent
    • Necessary delegation for service provision
    
    Services Used
    • Firebase (Google): Authentication, database, notifications
    • Apple: Apple ID sign-in
    
    5. DATA STORAGE AND DELETION
    
    Data Storage
    • Data is stored on Firebase's secure servers
    • May be stored on servers outside Japan
    
    Data Deletion
    • Personal information is deleted upon account deletion
    • Posted content can be deleted upon request
    • Some log information may be retained for legal requirements
    
    6. SECURITY
    
    Protection Measures
    • HTTPS encryption for communications
    • Firebase security rules for access control
    • Regular security updates
    
    User Responsibilities
    • Proper management of passwords and authentication information
    • Reporting suspicious activities
    
    7. CHILDREN'S PRIVACY
    
    We do not knowingly collect personal information from children under 13. If we discover use by someone under 13, we will delete the account.
    
    8. COOKIES AND TRACKING
    
    This app does not use cookies, but may collect anonymous usage statistics through Firebase analytics.
    
    9. POLICY CHANGES
    
    This policy may be updated as needed. Important changes will be notified within the app.
    
    10. CONTACT
    
    For privacy inquiries:
    • Please use the in-app reporting function
    • Response time: Within a reasonable period
    
    11. DATA PROTECTION OFFICER
    
    We currently do not have a designated Data Protection Officer, but for privacy concerns, please contact us using the above methods.
    
    12. GOVERNING LAW
    
    This Privacy Policy is governed by Japanese law.
    
    © 2025 Shaka. All rights reserved.
    """
}