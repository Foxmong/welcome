import Foundation

struct BasicTodo {
    let id: Int
    var title: String
    var isDone: Bool
}

var todos: [BasicTodo] = [
    BasicTodo(id: 1, title: "변수와 상수 복습", isDone: false),
    BasicTodo(id: 2, title: "옵셔널 예제 작성", isDone: true)
]

func remainingCount(in todos: [BasicTodo]) -> Int {
    todos.filter { !$0.isDone }.count
}

let selectedTodo: BasicTodo? = todos.first
let selectedTitle = selectedTodo?.title ?? "선택된 할 일이 없습니다"

print("선택: \(selectedTitle)")
print("남은 개수: \(remainingCount(in: todos))")
