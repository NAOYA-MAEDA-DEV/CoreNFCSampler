//
//  ContentView.swift
//  
//  
//  Created by Naoya Maeda on 2024/04/21
//  
//

import SwiftUI

struct ContentView: View {
  @StateObject private var reader = NFCTagReader()
  @FocusState private var textFieldIsFocused: Bool
  
  var body: some View {
    VStack(spacing: 0) {
      Text("Scan Result")
        .font(.largeTitle)
      Text(reader.readMessage ?? "")
      Spacer()
      if reader.sessionType == .write {
        VStack(alignment: .leading) {
          Text("Write Message")
          TextField(
            "Enter the message.",
            text: $reader.writeMesage
          )
          .focused($textFieldIsFocused)
          .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
      }
      if reader.nfcFormat == .ndef {
        Picker("Session Type", selection: $reader.sessionType) {
          ForEach(SessionType.allCases) { session in
            Text(session.rawValue).tag(session)
          }
        }
        .colorMultiply(.accentColor)
        .pickerStyle(.segmented)
        .padding()
      }
      Picker("NFC Format", selection: $reader.nfcFormat) {
        ForEach(NFCFormat.allCases) { session in
          Text(session.rawValue).tag(session)
        }
      }
      .colorMultiply(.accentColor)
      .pickerStyle(.segmented)
      .padding()
      Button(action: {
        reader.beginScanning()
      }, label: {
        Text("Scan")
          .frame(width: 200, height: 15)
      })
      .padding()
      .accentColor(Color.white)
      .background(Color.accentColor)
      .cornerRadius(.infinity)
      .disabled(!reader.readingAvailable)
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
