import SwiftUI

struct BasicTodoItem: Identifiable {
    let id = UUID()
    var title: String
    var isDone: Bool
}

struct BasicTodoListExampleView: View {
    @State private var todos: [BasicTodoItem] = [
        BasicTodoItem(title: "Swift 기본 타입", isDone: false),
        BasicTodoItem(title: "Optional 안전 처리", isDone: true)
    ]

    var body: some View {
        NavigationStack {
            List {
                if todos.isEmpty {
                    Text("할 일이 없습니다")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(todos) { todo in
                        HStack {
                            Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                            Text(todo.title)
                        }
                    }
                }
            }
            .navigationTitle("Swift Basics")
            .toolbar {
                Button("추가") {
                    todos.append(BasicTodoItem(title: "새 복습", isDone: false))
                }
            }
        }
    }
}
