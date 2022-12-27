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

(* 
   
let model = new Model();
let client = new Client();

schema Action:
  name: String
  args: Array(TypedAttr)
  body: SlighExpr
end
*)

let _ = {|
entity Account:
  balance: Int
  name: String
end

entity Transaction:
  srcAccount: Account
  dstAccount: Account
  amount: Decimal
end

process Accounts:
  accounts: Account

  def OpenAccount(newAct: Account):
    accounts.createAccount!(newAct)
  end

  def UpdateBalance(act: Account, balance: Decimal):
    6
  end
end

process Ledger:
  transactions: Transaction

  def Transfer(srcAct: Account, dstAct: Account, amount: Decimal):
    7
  end
end

def toImplMethod(action: Action):
  tsClassMethod(action.name, action.args, action.body)
end

def toImplAttr(attr: TypedAttribute):
  tsClassProp(attr.name, attr.type)
end

def toTsTypedAttr(attr: TypedAttribute):
  tsTypedAttr(attr.name, attr.type)
end

def toCtorBodyStmt(attr: TypedAttribute):
  let this = tsIden("this")
  let attrIden = tsIden(attr.name)
  let target = tsAccess(this, attrIden)

  tsAssignment(target, attrIden)
end

def impl():
  let methods = Model.actions.map(toImplMethod)
  let attrs = Model.variables.map(toImplAttr)
  
  let ctorArgs = Model.variables.map(toTsTypedAttr)
  let ctorBody = Model.variables.map(toCtorBodyStmt)
  let ctorStatements = tsStatementList(ctorBody)
  let ctor = tsClassMethod("constructor", ctorArgs, ctorStatements)

  let defs = attrs.concat(methods)
  let nextDefs = append(ctor, defs)

  tsClass("Client", nextDefs)
end

def toTsInterface(schema: Schema):
  let attrs = schema.attributes.map(toTsTypedAttr)

  tsInterface(schema.name, attrs)
end

implementation:
  typescript:
    {{* Model.schemas.map(toTsInterface) }}
    {{ impl() }}
  end
end

file another:
  typescript: let x = {{ "test" }} end
end

|}

(* 
  TODO: 
    * Effect system. Algebraic effects?
      - Convenient syntax for inlining a handler in the model, so model functionality
        is apparent without looking anywhere else, i.e. handle todos.create!(t) with todos.push(t)
      - Handle effects at thte process level, i.e. process client: handle create! with clientCreate
        this is how effects are "overridden" per each process
    * Model conformance test
      - This requires marking Actions in the implementation. Otherwise, how to create test?
*)

(* let () = Compiler.compile_str processes; *)

let () = Compiler.compile_file "effects.sl";