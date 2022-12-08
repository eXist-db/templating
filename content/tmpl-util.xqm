xquery version "3.1";

(:~
 : HTML templating utility module
 :
 : @contributor Juri Leino
:)
module namespace tmpl-util="http://exist-db.org/xquery/html-templating/utility";

declare
function tmpl-util:cast ($values as item()*, $targetType as xs:string) {
    for $value in $values
    return
        (: treat "" as empty sequence :)
        if ($targetType != "xs:string" and string-length($value) = 0)
        then ()
        else
            switch ($targetType)
                case "xs:string"   return string($value)
                case "xs:integer"
                case "xs:int"
                case "xs:long"     return xs:integer($value)
                case "xs:decimal"  return xs:decimal($value)
                case "xs:float"
                case "xs:double"   return xs:double($value)
                case "xs:date"     return xs:date($value)
                case "xs:dateTime" return xs:dateTime($value)
                case "xs:time"     return xs:time($value)
                case "element()"   return parse-xml($value)/*
                case "text()"      return text { string($value) }
                default            return $value
};

declare
function tmpl-util:first-result ($fns as function(*)*, $arg) as item()* {
    (: fold-left with no context :)
    (: fold-left($fns, (), function ($res, $next) {
        if (exists($res)) then $res else $next($arg)
    }) :)

    (: fold-left with dynamic context :)
    (: fold-left($fns, [$arg, ()], tut:resolve-reducer#2)?2 :)

    (: recursion :)
    if (empty($fns)) then ()
    else
        let $result := head($fns)($arg)
        return
            if (exists($result)) then $result
            else tmpl-util:first-result(tail($fns), $arg)
};

declare %private
function tmpl-util:resolve-reducer ($acc, $next) {
    if (exists($acc?2)) then $acc
    else array:put($acc, 2, $next($acc?1))
};

(: unused :)
declare
function tmpl-util:is-qname ($class as xs:string) as xs:boolean {
    matches($class, "^[^:]+:[^:]+")
};

declare
function tmpl-util:resolve-fn(
    $function-name as xs:string,
    $resolve as function(*),
    $max-arity as xs:integer
) as function(*)? {
    fold-left(2 to $max-arity, (), function ($fn, $arity) {
        if (exists($fn)) then $fn
        else $resolve($function-name, $arity)
    })
};
