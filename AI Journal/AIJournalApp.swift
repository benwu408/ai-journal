//
//  AIJournalApp.swift
//  AI Journal
//
//  Created by Ben Wu on 6/13/25.
//

import SwiftUI
import CoreData

@main
struct AIJournalApp: App {
    let persistentContainer = CoreDataManager.shared.persistentContainer
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
        }
    }
} 