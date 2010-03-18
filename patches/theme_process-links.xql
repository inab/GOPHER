declare function theme:process-links($attribs as attribute()*) {
    for $attr in $attribs
    return
        if (local-name($attr) = ('src', 'href')) then (
            let $evaled := replace($attr/string(),'\{\$context\}',$theme:context)
            let $theval := if(matches($evaled, "^(/|\w+:)")) then $evaled else concat($theme:context, $evaled)
            return
                attribute { node-name($attr) } {
                    $theval
                }
        ) else
            $attr
};
