// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import JSONFoundation
import LocalServerServiceInterface
import SwiftUI
import ToolFoundation

#if DEBUG
let url = URL(filePath: "/path/to/some-file.txt")

typealias Status = UnknownTool.Use.Status

let longJSON = try! JSONDecoder().decode(JSON.Value.self, from: """
  {
    "id": "usr_7829384756",
    "timestamp": "2025-09-28T14:23:45.678Z",
    "username": "alexandra_martinez_92",
    "email": "alex.martinez@techcorp.example.com",
    "description": "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium.",
    "age": 31,
    "isActive": true,
    "balance": 45678.92,
    "tags": ["developer", "python", "machine-learning", "photography", "hiking"],
    "address": {
      "street": "4892 Oak Boulevard",
      "city": "San Francisco",
      "state": "CA",
      "zipCode": "94102",
      "coordinates": {
        "latitude": 37.7749,
        "longitude": -122.4194
      }
    },
    "phoneNumbers": ["+1-415-555-0142", "+1-628-555-0198"],
    "lastLogin": "2025-09-27T09:15:32.000Z",
    "preferences": {
      "theme": "dark",
      "language": "en-US",
      "notifications": {
        "email": true,
        "sms": false,
        "push": true
      }
    },
    "bio": "Passionate software engineer with over 8 years of experience in building scalable web applications and distributed systems. Specialized in Python, JavaScript, and cloud architecture. When not coding, you can find me exploring hiking trails, experimenting with photography, or contributing to open-source projects. I believe in writing clean, maintainable code and fostering collaborative team environments. Currently working on AI/ML projects and always eager to learn new technologies and methodologies.",
    "projects": [
      {
        "name": "DataFlow Pipeline",
        "status": "in-progress",
        "completion": 67.5
      },
      {
        "name": "API Gateway v2",
        "status": "completed",
        "completion": 100
      }
    ],
    "securityToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI3ODI5Mzg0NzU2IiwibmFtZSI6IkFsZXhhbmRyYSBNYXJ0aW5leiIsImlhdCI6MTcyNzUzMTAyNSwiZXhwIjoxNzI3NTM0NjI1LCJhdWQiOiJhcGkudGVjaGNvcnAuY29tIiwiaXNzIjoiYXV0aC50ZWNoY29ycC5jb20iLCJqdGkiOiI1NWY4YzNkNC04OTJhLTRiNmUtYmQ3Zi0xMjNhNDU2Nzg5MGEiLCJzY29wZSI6InJlYWQgd3JpdGUgZGVsZXRlIGFkbWluIn0.x8K_2nqVwRp5mTc3yLbQfHgJ9uXvZ4aDkEiPmNs7w9k",
    "metadata": {
      "createdAt": "2020-03-15T10:30:00.000Z",
      "updatedAt": "2025-09-28T14:23:45.678Z",
      "version": "3.2.1",
      "source": "web_registration"
    }
  }
  """.utf8Data)

let shortJSON = try! JSONDecoder().decode(JSON.Value.self, from: """
  {
    "name": "John Smith",
    "age": 28,
    "active": true,
    "email": "john@example.com",
    "score": 92.5
  }
  """.utf8Data)

#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      DefaultToolUseView(toolUse: DefaultToolUseViewModel(
        toolName: "test-tool",
        status: Status.Just(.notStarted),
        input: shortJSON))

      DefaultToolUseView(toolUse: DefaultToolUseViewModel(
        toolName: "test-tool",
        status: Status.Just(.pendingApproval),
        input: shortJSON))

      DefaultToolUseView(toolUse: DefaultToolUseViewModel(
        toolName: "test-tool",
        status: Status.Just(.running),
        input: shortJSON))

      DefaultToolUseView(toolUse: DefaultToolUseViewModel(
        toolName: "test-tool",
        status: Status.Just(.completed(.success(longJSON))),
        input: shortJSON))

      DefaultToolUseView(toolUse: DefaultToolUseViewModel(
        toolName: "test-tool",
        status: Status.Just(.completed(.failure(AppError("Tool call failed")))),
        input: shortJSON))
    }
  }
  .frame(minWidth: 200, minHeight: 500)
  .padding()
}
#endif
