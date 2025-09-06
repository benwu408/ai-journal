import SwiftUI

struct WhyModalView: View {
    @Binding var whyText: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("What's contributing to how you feel?")
                    .font(.headline)
                    .padding(.horizontal)
                
                // Text input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Describe what's influencing your mood:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextEditor(text: $whyText)
                        .frame(minHeight: 200)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .onChange(of: whyText) { oldValue, newValue in
                            print("🤔 Why text changed: '\(newValue)'")
                        }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Why do you feel this way?")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Done") {
                    isPresented = false
                }
                .fontWeight(.semibold)
            )
        }
    }
} 