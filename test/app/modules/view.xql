xquery version "3.1";

import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace apps="http://exist-db.org/xquery/html-templating/apps";


import module namespace test="test" at "test.xqm";

declare namespace app="app";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

(:~
 : A wrapping template function that just returns a map will
 : - extend the model and
 : - process all child nodes
 :)
declare
    %templates:wrap
function app:init-data($node as node(), $model as map(*)) {
    map {
        "addresses": (
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
        ),
        "data": map {
            "test": "TEST1",
            "nested": map {
                "test": "TEST2"
            }
        }
    }
};

declare variable $app:lookup :=
    function ($name as xs:string, $arity as xs:integer) as function(*)? {
        function-lookup(xs:QName($name), $arity)
    };

let $config := map {
    $templates:CONFIG_APP_ROOT      : $test:app-root,
    $templates:CONFIG_FILTER_ATTRIBUTES : true(),
    $templates:CONFIG_STOP_ON_ERROR : true()
}

(: read request parameter first in order to test three states
 : true, false and unset / default
 :)
let $class-syntax-option := request:get-parameter('classLookup', ())
let $config-with-class-syntax-maybe-set := 
    if (empty($class-syntax-option)) then (
        $config
    ) else (
        map:put($config, $templates:CONFIG_USE_CLASS_SYNTAX, xs:boolean($class-syntax-option))
    )

(:
 : The HTML is passed in the request from the controller.
 : Run it through the templating system and return the result.
 :)
return
templates:apply(
    request:get-data(),
    $app:lookup,
    map {
        "page-title": "This is the title",
        "my-model-item": 'xxx', 
        'includes': map{ 'menubar' : 'included.html' }
    },
    $config-with-class-syntax-maybe-set)

(: alternative :)
(:
templates:render(
    request:get-data(),
    map { "my-model-item": 'xxx' },
    map {
        $templates:CONFIG_QNAME_RESOLVER : xs:QName(?),
        $templates:CONFIG_APP_ROOT       : $test:app-root,
        $templates:CONFIG_STOP_ON_ERROR  : true()
    })
:)
