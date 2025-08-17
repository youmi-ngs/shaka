//
//  TermsAgreementView.swift
//  Shaka
//
//  Created by Assistant on 2025/08/18.
//

import SwiftUI

struct TermsAgreementView: View {
    @Binding var hasAgreedToTerms: Bool
    @State private var showTerms = false
    @State private var showPrivacy = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "camera.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("Welcome to Shaka")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Share your photography journey")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            VStack(spacing: 20) {
                Text("By continuing, you agree to our")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    Button("Terms of Service") {
                        showTerms = true
                    }
                    .font(.footnote)
                    
                    Text("and")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Button("Privacy Policy") {
                        showPrivacy = true
                    }
                    .font(.footnote)
                }
                
                Button(action: {
                    hasAgreedToTerms = true
                    UserDefaults.standard.set(true, forKey: "hasAgreedToTerms")
                }) {
                    Text("I Agree & Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showTerms) {
            LegalView(type: .terms)
        }
        .sheet(isPresented: $showPrivacy) {
            LegalView(type: .privacy)
        }
    }
}

#Preview {
    TermsAgreementView(hasAgreedToTerms: .constant(false))
}