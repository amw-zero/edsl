open Edsl

(* let working = {|
entity Other:
  val: Int
end

domain Test:
  state: Int

  def change(a: Int):
    state.create!(5)
  end
end

def topLevel():
  let x = 5
end

def other(i: Int):
  i
end

process client:
  typescript:
    class Env {
      {{ x: Int }}
      {{ y: Int }}
    }
  end
end

process server:
  typescript:
    app.post({{ other(5) }})
  end
end

|} *)

(* let eval = {|
// Model
entity Todo:
  name: String
end

domain Test:
  todos: Todo[]

  def addTodo(t: Todo):
    todos.create!(t)
  end
end

// Effect definition - how is an effect executed
// across implementation components?
effect create!<'a>(state: SystemState<'a>, val: 'a):
  model: 
    state.push(val)
  end

  // Client code generated from 
  client:
    typescript:
      let resp = fetch({{ state.name }}, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(val),
      });
      let data = await resp.json();

      client.todos.push(data);
    end
  end

  server:
    // Generate endpoint code
  end
end

// Helpers to 
def toTsTypedIden(var: Variable)
  typescript:
    {{ var.name }}: {{ var.type }}
  end
end

def toTsAction(act: Action)
  typescript:
    async {{ act.name }}({{ act.args.map(toTsTypedIden) }}) {
      {{ act.body }}
    }
  end
end

// Generates a client.ts file
process client:
  typescript:
    class Client {
      {{ Model.variables.map(toTsTypedIden) }}

      {{ Model.actions.map(toTsAction) }}
    }
  end
end

// Generates a server.ts file
process server:
  // generate web server bootstrap
end
|} *)

(* 
env = key -> value
Model = {
  Other: {
    val: Int
  },
  Todo: {
    other: Other
  }
}
*)

let eval = {|
entity Other:
  val: Int
end

entity Todo:
  name: String
  other: Other
end

domain Todos:
  todos: Todo
end

def toName(a: Schema):
  a.name
end

def toTsClassBody(a: Attribute):
  tsClassProp(a.name, a.type)
end

def toTsClass(s: Schema):
  let body = s.attributes.map(toTsClassBody)
  
  typescript:
    {{ tsClass(s.name, body) }} 
  end
end

def attrName(a: Attribute):
  a.name
end

process cli:
  typescript:
    let allModelNames = {{ Model.schemas.map(toName) }}
    let todoName = {{ Todo.name }}
    let todoAttrs = {{ Todo.attributes.map(attrName) }}

   let allTypes = {{ Model.schemas.map(toTsClass )}}
  end
end
|}

(*

{
  Todo: {
    name: Todo,
    attrs: [
      { name: "name", type: Primitive(String) },
    ]
  },
  Todos: {
    name: Todos,
    attrs: [
      { name: "todo", type: Custom(Todo) }
    ]
  },
  Model: {
    name: Model,
    attrs: [
      { name: "schemas", type: Array(Schema([Todo, Todos])) }
    ]
  }
}   


*)

(* next process client:
  typescript:
    let names = {{ Model.schemas.map(toName) }}
  end

  def toTsClass(a: Schema):
    tsclass(a.name, )

    typescript:
      tsclass 
      class {{ a.name }} {

      }
    end
end
end *)

(* 
  TODO: 
    Replace tsclassdef_of_expr with syntax construction functions, a la template
      Haskell and Nim. Have to create TSClassProp for example, and that context
      can't be created in a quasi-quote.
*)

let () = Compiler.compile eval;
