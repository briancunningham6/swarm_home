
// Import dependencies
import "../css/app.css"

// Import Phoenix HTML helpers (optional)
import "phoenix_html"
// Import Phoenix LiveView
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})

// Connect if there are any LiveView elements on the page
liveSocket.connect()

// Expose liveSocket on window for web console debug logs and latency simulation:
window.liveSocket = liveSocket
