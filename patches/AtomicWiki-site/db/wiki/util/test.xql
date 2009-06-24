xquery version "1.0";

<div xmlns="http://www.w3.org/1999/xhtml">
    <p>Request URI: {request:get-uri()}</p>
    <h2>Parameters</h2>
    <table>
    {
        for $param in request:get-parameter-names()
        return
            <tr>
                <td>{$param}</td>
                <td>{request:get-parameter($param, ())}</td>
            </tr>
    }
    </table>
</div>