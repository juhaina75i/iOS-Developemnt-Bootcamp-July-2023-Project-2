//
//  AppIconView.swift
//  wheatherApp
//
//  Created by Juhaina on 02/02/1445 AH.
//

import Foundation
import SwiftUI

struct AppIconView: View {
    var body: some View {
        VStack{
            Image("logo")  // Replace "AppIcon" with the name of your app icon asset
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
            Text("Weather App")
                .foregroundColor(.blue)
        }
    }
}

struct AppIconView_Previews: PreviewProvider {
    static var previews: some View {
        AppIconView()
    }
}
