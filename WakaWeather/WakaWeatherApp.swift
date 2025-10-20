//
//  WakaWeatherApp.swift
//  WakaWeather
//
//  Created by Raphael Andrews on 19/10/2025.
//

import SwiftUI

@main
struct WakaWeatherApp: App {
    @AppStorage("isDarkMode") private var isDarkMode = false
    var body: some Scene
    {
        WindowGroup
        {
            
            TabView
            {
                Tab
                {
                    homePageView()
                        .preferredColorScheme(isDarkMode ? .dark : .light)
                }
            label:
                {
                    Image(systemName: "house")
                    Text("Home")
                }
                Tab
                {
                    radarPageView()
                        .preferredColorScheme(isDarkMode ? .dark : .light)
                }
            label:
                {
                    Image(systemName: "map")
                    Text("Radar")
                }
                Tab
                {
                    ConfidenceView()
                        .preferredColorScheme(isDarkMode ? .dark : .light)
                }
            label:
                {
                    Image(systemName: "powermeter")
                    Text("Confidence")
                }
                Tab
                {
                    MessagePageView()
                        .preferredColorScheme(isDarkMode ? .dark : .light)
                }
            label:
                {
                    Image(systemName: "bell")
                    Text("Messages")
                }
                
            }
            
        }
    }
}
