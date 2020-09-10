//
// Spica for iOS (Spica)
// File created by Lea Baumgart on 24.08.20.
//
// Licensed under the GNU General Public License v3.0
// Copyright © 2020 Lea (Adrian) Baumgart. All rights reserved.
//
// https://github.com/SpicaApp/Spica-iOS
//

import SwiftUI

struct ColorPickerView: View {
    @ObservedObject var controller: ColorPickerController

    var body: some View {
        if #available(iOS 14.0, *) {
            // ColorPicker("Accent color", selection: $controller.color)
            VStack {
                ColorPicker(selection: $controller.color, label: {
					Text(SLocale(.ACCENT_COLOR)).bold().font(.title)
				}).background(Color.clear).frame(maxWidth: .infinity, maxHeight: 50, alignment: .center)
                Spacer()
                Button(action: {
                    controller.color = Color(UIColor.systemBlue)
				}) {
					Text(SLocale(.RESET_ACTION)).foregroundColor(.white)
                }.frame(maxWidth: .infinity).padding().background(Color.accentColor).cornerRadius(12)
            }.padding()
        } else {
            // Fallback on earlier versions
            Text("Not supported")
        }
    }
}

struct ColorPickerView_Previews: PreviewProvider {
    static var previews: some View {
        ColorPickerView(controller: .init(color: Color(UIColor.systemBlue)))
    }
}
