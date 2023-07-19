xquery version "3.1";

(:~
 : HTML templating module: cross app resolution
 :
 : @author Wolfgang Meier
 : @contributor Juri Leino
 :)
module namespace tmpl-apps="http://exist-db.org/xquery/html-templating/apps";

declare namespace expath="http://expath.org/ns/pkg";
declare namespace repo="http://exist-db.org/xquery/repo";

import module namespace templates="http://exist-db.org/xquery/html-templating";


declare variable $tmpl-apps:default-not-found := 
    request:get-context-path() || "/404.html#";

(:~
 : Resolve the expath application package identified by $abbrev. If an installed
 : application is found, a property is added to the model. The name of the property
 : will correspond to $abbrev and its value to the absolute URI path at which the
 : root of the application can be found.
 :
 : Use ${apps?my-app} to expand a URL to my-app
 :
 : $abbrev may list more than one package abbreviation separated by ",".
 :
 : @returns an absolute URI path or request:get-context-path() || "/404.html#" if not found
 :)
declare 
    %templates:wrap
function tmpl-apps:by-abbrev ($node as node(), $model as map(*), $abbrev as xs:string) as map(*) {
    let $packages := tmpl-apps:get-packages()
    let $abbrevList := tokenize($abbrev, '\s*,\s*')
    let $resolved :=
        for $abbrev in $abbrevList
        let $url := tmpl-apps:get-url-from-repo($model, $packages, $abbrev)
        return
            map { $abbrev : $url }

    return map:put($model, 'apps', map:merge($resolved))
};

declare function tmpl-apps:get-url-from-repo(
    $model as map(*),
    $packages as document-node()*,
    $abbrev as xs:string
) as xs:string* {
    let $package := $packages/expath:package[@abbrev = $abbrev]
    return
        if (empty($package)) then tmpl-apps:not-found($model, $abbrev)
        else
            let $repo := tmpl-apps:safe-load-package-info($package/@name, "repo.xml")
            return
                if (empty($repo)) then tmpl-apps:not-found($model, $abbrev)
                else string-join((
                    request:get-context-path(),
                    request:get-attribute("$exist:prefix"), 
                    "/", $repo//repo:target
                ))
};

declare function tmpl-apps:not-found ($model, $abbrev) {
    $tmpl-apps:default-not-found (: ,$abbrev :)
};

declare function tmpl-apps:get-packages () as document-node()* {
    for $uri in repo:list()
    return tmpl-apps:safe-load-package-info($uri, "expath-pkg.xml")
};

declare function tmpl-apps:safe-load-package-info ($uri as xs:string, $resource as xs:string) as node()? {
    try {
        repo:get-resource($uri, $resource)
        => util:binary-to-string()
        => parse-xml()
    }
    catch * { () }
};
