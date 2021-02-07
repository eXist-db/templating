xquery version "3.1";

declare namespace test="https://exist-db.org/xquery/html-templating/test";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace templates="http://exist-db.org/xquery/html-templating";

declare option output:method "html5";
declare option output:media-type "text/html";

declare 
    %templates:wrap
function test:init-data($node as node(), $model as map(*)) {
    let $addresses := (
        map {
            "name": "Berta Muh",
            "street": "An der Viehtränke 13",
            "city": "Kuhweide"
        },
        map {
            "name": "Rudi Rüssel",
            "street": "Am Zoo 45",
            "city": "Tierheim"
        }
    )
    return map {
        "addresses": $addresses
    }
};

declare 
    %templates:wrap
function test:print-name($node as node(), $model as map(*)) {
    $model("address")?name
};
declare 
    %templates:wrap
function test:print-city($node as node(), $model as map(*)) {
    $model("address")?city
};
declare 
    %templates:wrap
function test:print-street($node as node(), $model as map(*)) {
    $model("address")?street
};

declare 
    %templates:wrap
    %templates:default("language", "en")
function test:hello($node as node(), $model as map(*), $language as xs:string) {
    switch($language)
        case "de" return
            "Willkommen"
        case "pl" return
            "Witam"
        default return
            "Welcome"
};

declare 
    %templates:wrap
function test:numbers($node as node(), $model as map(*), $n1 as xs:integer, $n2 as xs:double) {
    ($n1 treat as xs:integer) + ($n2 treat as xs:double)
};

declare 
    %templates:wrap
function test:date($node as node(), $model as map(*), $date as xs:date) {
    day-from-date($date)
};

declare function test:custom-model($node as node(), $model as map(*)) {
    $model?('my-model-item')
};

let $config := map {
    $templates:CONFIG_STOP_ON_ERROR: true()
}
let $lookup := function($name as xs:string, $arity as xs:integer) {
    try {
        function-lookup(xs:QName($name), $arity)
    } catch * {
        ()
    }
}
(:
 : The HTML is passed in the request from the controller.
 : Run it through the templating system and return the result.
 :)
let $content := request:get-data()
return
    templates:apply($content, $lookup, map { "my-model-item": 'xxx' }, $config)