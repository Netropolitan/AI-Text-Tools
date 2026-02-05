#Requires AutoHotkey v2.0

/**
 * HttpClient - HTTP request wrapper using WinHttp
 *
 * Uses WinHttp.WinHttpRequest.5.1 which is faster than MSXML2
 * and doesn't have caching or redirect issues.
 */
class HttpClient {
    static DefaultTimeout := 30000  ; 30 seconds

    /**
     * Make an HTTP request
     * @param method HTTP method (GET, POST, PUT, DELETE)
     * @param url Full URL to request
     * @param body Request body (string or will be JSON.Dump'd if object)
     * @param headers Map of header name => value
     * @param timeout Timeout in milliseconds
     * @returns {status, body, headers, error}
     */
    static Request(method, url, body := "", headers := Map(), timeout := 0) {
        if timeout = 0
            timeout := this.DefaultTimeout

        result := {
            status: 0,
            body: "",
            headers: "",
            error: ""
        }

        try {
            whr := ComObject("WinHttp.WinHttpRequest.5.1")

            ; Set timeouts BEFORE Open for reliability
            ; Parameters: ResolveTimeout, ConnectTimeout, SendTimeout, ReceiveTimeout (all in ms)
            whr.SetTimeouts(timeout, timeout, timeout, timeout)

            ; Use synchronous mode for reliability (avoids 0x8000000A errors)
            whr.Open(method, url, false)  ; false = synchronous

            ; Set custom headers
            for name, value in headers
                whr.SetRequestHeader(name, value)

            ; Serialize body if it's an object (not string)
            sendBody := ""
            if body != "" {
                if IsObject(body) {
                    sendBody := JSON.Dump(body)
                    ; Set Content-Type if not already set via headers
                    if !headers.Has("Content-Type")
                        whr.SetRequestHeader("Content-Type", "application/json")
                } else {
                    sendBody := body
                }
            }

            ; Send request (blocks until complete in sync mode)
            whr.Send(sendBody)

            result.status := whr.Status
            result.body := whr.ResponseText
            result.headers := whr.GetAllResponseHeaders()
        } catch as e {
            result.error := e.Message
            result.status := 0
        }

        return result
    }

    /**
     * Make a GET request
     * @param url URL to request
     * @param headers Optional headers Map
     * @returns Response object
     */
    static Get(url, headers := Map()) {
        return this.Request("GET", url, "", headers)
    }

    /**
     * Make a POST request
     * @param url URL to request
     * @param body Request body (string or object to JSON serialize)
     * @param headers Optional headers Map
     * @returns Response object
     */
    static Post(url, body, headers := Map()) {
        return this.Request("POST", url, body, headers)
    }

    /**
     * Make a POST request with JSON body and parse JSON response
     * Convenience method for AI API calls
     * @param url URL to request
     * @param body Object to send as JSON
     * @param headers Headers Map (Authorization should be included)
     * @returns {success, data, error, status}
     */
    static PostJSON(url, body, headers := Map()) {
        response := this.Post(url, body, headers)

        result := {
            success: false,
            data: "",
            error: "",
            status: response.status
        }

        if response.error {
            result.error := response.error
            return result
        }

        if response.status >= 200 && response.status < 300 {
            try {
                result.data := JSON.Load(response.body)
                result.success := true
            } catch as e {
                result.error := "JSON parse error: " e.Message
            }
        } else {
            ; Try to parse error from response body
            try {
                errData := JSON.Load(response.body)
                ; Handle both Map (from cJson) and Object formats
                hasError := (errData is Map) ? errData.Has("error") : errData.HasProp("error")
                if hasError {
                    errVal := errData["error"]
                    if IsObject(errVal) {
                        hasMsg := (errVal is Map) ? errVal.Has("message") : errVal.HasProp("message")
                        if hasMsg
                            result.error := errVal["message"]
                        else
                            result.error := String(errVal)
                    } else {
                        result.error := String(errVal)
                    }
                } else {
                    result.error := "HTTP " response.status
                }
            } catch {
                result.error := "HTTP " response.status ": " SubStr(response.body, 1, 200)
            }
        }

        return result
    }
}
