// Minimal AWS Lambda Web Function HTTP server.
//
// You can replace this with any code or framework that starts an HTTP server.
import http from 'node:http';

// Lambda sends requests to port 3000. Set LOCAL_PORT for local development.
const port = Number(process.env.LOCAL_PORT ?? 3000);

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ message: 'Hello from Lambda Web!', path: req.url }));
});

server.listen(port, () => {
  console.log(`listening on port ${port}`);
});
