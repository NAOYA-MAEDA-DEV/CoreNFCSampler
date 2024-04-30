//
//  Utility.swift
//  
//  
//  Created by Naoya Maeda on 2024/04/21
//  
//

import Foundation

enum SessionType: String, CaseIterable, Identifiable  {
  case read
  case write
  case lock
  var id: String { rawValue }
}

enum NFCFormat: String, CaseIterable, Identifiable  {
  case ndef
  case suica
  var id: String { rawValue }
}
