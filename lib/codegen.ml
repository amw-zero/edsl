open Core

let print_list delim  l = String.concat delim l

let rec string_of_boolexp t = match t with
  | BTrue -> "true"
  | BFalse -> "false"
  | BIf (t1, t2, t3) -> Printf.sprintf "if %s then %s else %s" (string_of_boolexp t1) (string_of_boolexp t2) (string_of_boolexp t3)

let string_of_generic_type n = match n with
  | "Set" -> "Array"
  | _ -> failwith (Printf.sprintf "Unknown generic type mapping: %s" n)

let rec string_of_type t = match t with
  | STInt -> "number"
  | STCustom s -> s
  | STString -> "string"
  | STDecimal -> "number"
  | STVariant(n, _) -> Printf.sprintf "Variant: %s" n
  | STGeneric(n, ts) -> Printf.sprintf "%s<%s>" (string_of_generic_type n) (String.concat ", " (List.map string_of_type ts))

let string_of_typed_attr ta =
  Printf.sprintf "%s: %s" ta.name (string_of_type ta.typ)

let string_of_variant_tag vt =
  Printf.sprintf "export type %s = {\n%s\n}"
    vt.tname
    (String.concat "\n" ((Printf.sprintf "type: \"%s\";" vt.tname) :: (List.map string_of_typed_attr vt.tattrs)))

  (* Only supporting codegen to TS right now *)
let rec string_of_expr e = match e with
  | Let(name, body) -> Printf.sprintf "let %s = %s;" name (string_of_expr body)
  | Assignment(name, value) ->
    Printf.sprintf "this.%s = %s" name (string_of_expr value)
  | Iden(i, too) -> (match too with
    | Some(t) -> Printf.sprintf "%s: %s" i (string_of_type t)
    | None -> i)
  | Num(n) -> string_of_int n
  | If(e1, e2, e3) -> (match e3 with
    | Some(elseE) -> Printf.sprintf "if  %s:\n %s\nelse:\n  %send" (string_of_expr e1) (string_of_expr e2) (string_of_expr elseE)
    | None -> Printf.sprintf "if %s:\n %s\nend" (string_of_expr e1) (string_of_expr e2))
  | StmtList(ss) -> string_of_stmt_list ss
  | Process(n, defs) -> Printf.sprintf "export class %s {\n %s\n  %s\n}" n (process_constructor defs) (String.concat "\n" (List.map string_of_proc_def defs))
  | Entity(n, attrs) ->  Printf.sprintf "export interface %s {\n\t%s\n}" n (print_list "\n" (List.map string_of_typed_attr attrs))
  | Variant(n, vs) ->
    Printf.sprintf "export type %s = %s\n\n%s"
      n
      (String.concat " | " (List.map (fun vt -> vt.tname) vs))
      (String.concat "\n" (List.map string_of_variant_tag vs))
  | Call(name, args) ->
    if List.exists (fun n -> n = name) Interpreter.builtin_funcs then
      string_of_builtin name args
    else 
      name ^ "(" ^ String.concat ", " (List.map string_of_expr args) ^ ")"
  | FuncDef({fdname; fdargs; fdbody}) -> Printf.sprintf "function %s(%s):\n\t%s\nend\n" fdname (String.concat ", " (List.map string_of_typed_attr fdargs)) (string_of_stmt_list fdbody)
  | Access(e, i) -> Printf.sprintf "%s.%s" (string_of_expr e) i
  | String(s) -> Printf.sprintf "\"%s\"" s
  | TS(tses) -> String.concat "\n\n" (List.map string_of_ts_expr tses)
  | _ -> failwith (Printf.sprintf "Unable to generate code for expr: %s" (Util.string_of_expr e))
and string_of_proc_def def = match def with
| ProcAttr({ name; typ }) -> Printf.sprintf "%s: %s" name (string_of_type typ)
| ProcAction({ aname; body; args}) -> Printf.sprintf "%s(%s) {\n\t%s\n}" aname (String.concat ", " (List.map string_of_typed_attr args)) (String.concat "\n" (List.map string_of_expr body))
and string_of_stmt_list sl =
  let rev_list = List.rev sl in
  let ret_stmt = List.hd rev_list in 
  let rest = List.tl rev_list in
  let ret_str = Printf.sprintf "return %s;" (string_of_expr ret_stmt) in
  let rest_strs = List.map string_of_expr rest in
  let all_strs = ret_str :: rest_strs in

  String.concat "\n" (List.rev all_strs)

and string_of_builtin n args =
  match n with
  | "append" -> 
    let arr = List.nth args 0 |> string_of_expr in
    let elem = List.nth args 1 |> string_of_expr in

    Printf.sprintf {|
    (() => {
    let a = [...%s];
    a.push(%s);

    return a;
    })();
    |} arr elem
  | _ -> failwith (Printf.sprintf "Attempted to compile unknown builtin func: %s" n)  

and string_of_ts_expr e = match e with
  | TSIden({iname; itype}) -> (match itype with
    | Some(t) -> Printf.sprintf "%s: %s" iname (string_of_tstype t)
    | None -> Printf.sprintf "%s" iname)
  | TSNum(n) -> string_of_int n
  | TSIf(e1, e2, e3) -> (match e3 with
    | Some(elseE) -> Printf.sprintf "if (%s) {\n %s}\nelse {\n%s\n}" (string_of_ts_expr e1) (string_of_ts_expr e2) (string_of_ts_expr elseE)
    | None -> Printf.sprintf "if (%s) {\n %s\n}" (string_of_ts_expr e1) (string_of_ts_expr e2))
  | TSLet(v, ie) -> Printf.sprintf "let %s = %s" v (string_of_ts_expr ie)
  | TSStmtList(ss) -> String.concat "\n" (List.map string_of_ts_expr ss)
    (* let rev_list = List.rev ss in
    let ret_stmt = List.hd rev_list in 
    let rest = List.tl rev_list in
    let ret_str = Printf.sprintf "return %s;" (string_of_ts_expr ret_stmt) in
    let rest_strs = List.map string_of_ts_expr rest in
    let all_strs = ret_str :: rest_strs in

    String.concat "\n" (List.rev all_strs) *)
  | TSClass(n, ds) -> Printf.sprintf "class %s{%s}" n (String.concat "\n" (List.map string_of_tsclassdef ds))
  | TSMethodCall(recv, m, args) -> Printf.sprintf "%s.%s(%s)" recv m (List.map string_of_ts_expr args |> print_list ", ")
  | TSFuncCall(f, args) -> Printf.sprintf "%s(%s)" f (List.map string_of_ts_expr args |> print_list ", ")
  | TSArray(es) -> Printf.sprintf "[%s]" (String.concat ", " (List.map string_of_ts_expr es))
  | TSString(s) -> Printf.sprintf "\"%s\"" s
  | TSAccess(e1, e2) -> Printf.sprintf "%s.%s" (string_of_ts_expr e1) (string_of_ts_expr e2)
  | TSAssignment(e1, e2) -> Printf.sprintf "%s = %s;" (string_of_ts_expr e1) (string_of_ts_expr e2)
  | TSInterface(n, attrs) -> Printf.sprintf "interface %s {\n %s\n}" n (String.concat "\n" (List.map string_of_ts_typed_attr attrs))
  | TSClosure(args, body) -> Printf.sprintf "(%s) => {\n  %s\n}" (String.concat ", " (List.map string_of_tsiden args)) (print_list "\n" (List.map string_of_ts_expr body))
  | TSAwait(e) -> Printf.sprintf "await %s" (string_of_ts_expr e)
  | TSAsync(e) -> Printf.sprintf "async %s" (string_of_ts_expr e)
  | TSObject(props) -> Printf.sprintf "{%s}" (String.concat ",\n" (List.map string_of_obj_prop props))
  | TSNew(c, args) -> Printf.sprintf "new %s(%s)" c (String.concat ", " (List.map string_of_ts_expr args))
  | SLSpliceExpr(_) -> "SLSpliceExpr"
  | SLExpr(e) -> string_of_expr e

and string_of_obj_prop p = Printf.sprintf "%s: %s" p.oname (string_of_ts_expr p.oval)


and string_of_tsiden {iname; itype} = match itype with
  | Some(t) -> Printf.sprintf "%s: %s" iname (string_of_tstype t)
  | None -> Printf.sprintf "%s" iname  

and string_of_tstype tst = match tst with
  | TSTNumber -> "number"
  | TSTCustom c -> c
  | TSTString -> "string"
  | TSTGeneric(n, types) -> Printf.sprintf "%s<%s>"
    n
    (String.concat ", " (List.map string_of_tstype types))

and string_of_ts_typed_attr ta = Printf.sprintf "%s: %s" ta.tsname (string_of_tstype ta.tstyp)

and string_of_tsclassdef cd = match cd with
  | TSClassProp(n, typ) -> Printf.sprintf "%s: %s" n (string_of_tstype typ)
  | TSClassMethod(nm, args, body) -> Printf.sprintf "%s(%s) { %s }" nm (String.concat ", " (List.map string_of_ts_typed_attr args)) (List.map string_of_ts_expr body |> print_list "\n")
  | CDSLExpr(_) -> "CDSLExpr remove"  
and process_constructor defs = 
  let attrs = Process.filter_attrs defs in
  let ctor_args = String.concat ", " (List.map string_of_typed_attr attrs) in
  let ctor_body = String.concat "\n" (List.map (fun attr -> 
      Printf.sprintf "this.%s = %s;" attr.name attr.name) attrs) in

  Printf.sprintf "constructor(%s) {\n  %s\n}" ctor_args ctor_body  

let string_of_model model_ast = String.concat "\n\n" (List.map string_of_expr model_ast)

let rec tstype_of_sltype typ = match typ with
  | Some(t) -> (match t with
    | STInt -> Some(TSTNumber)
    | STString -> Some(TSTString)
    | STDecimal -> Some(TSTNumber)
    | STCustom(c) -> Some(TSTCustom(c))
    | STVariant(n, _) -> Some(TSTCustom(n))
    | STGeneric(n, types) -> Some(TSTGeneric(n, List.filter_map (fun t -> tstype_of_sltype (Some(t))) types)))
  | None -> None

(* Currently unused, but converts a Sligh expression to a TS one *)
let rec tsexpr_of_expr e = match e with
  | Let(var, e) -> TSLet(var, tsexpr_of_expr e)
  | StmtList(es) -> TSStmtList(List.map tsexpr_of_expr es)
  | Iden(name, typ) -> TSIden({iname=name; itype=tstype_of_sltype typ})
  | Num(i) -> TSNum(i)
  | If(e1, e2, e3) -> (match e3 with
    | Some(elseE) -> TSIf(tsexpr_of_expr e1, tsexpr_of_expr e2, Some(tsexpr_of_expr elseE))
    | None -> TSIf(tsexpr_of_expr e1, tsexpr_of_expr e2, None))
  | Array(es) -> TSArray(List.map tsexpr_of_expr es)
  | String(s) -> TSString(s)
  | Assignment(v, e) -> TSAssignment(TSIden({iname=Printf.sprintf "this.%s" v;itype=None}), tsexpr_of_expr e)

  (* Unsure about this - why doesn't Access have an expr on the right hand side? *)
  | Access(e, accessor) -> TSAccess(tsexpr_of_expr e, TSIden({iname=accessor; itype=None}))

  (* Unsure if this should be StmtList *)
  | TS(tses) -> TSStmtList(tses)

  (* Let the Codegen engine handle calls for now, because of UCS hard to tell if func or method call*)
  | Call(name, args) -> TSFuncCall(name, List.map tsexpr_of_expr args)

  (* Not handling these, but should *)
  | FuncDef(_) -> failwith "Not handling FuncDef to TS"
  | Case(_, _) -> failwith "Not handling Case to TS"
  
  (* Not handling these, and probably should never *)
  | Effect(_) -> failwith "Not handling Effect to TS"
  | Implementation(_) -> failwith "Not handling Implementation to TS"
  | File(_) -> failwith "Not handling File to TS"
  | Process(_, _) -> failwith "Not handling Process to TS - maybe convert to class"
  | Entity(_, _) -> failwith "Not handling Entity to TS"
  | Variant(_, _) -> failwith "Not handling Variant to TS"
