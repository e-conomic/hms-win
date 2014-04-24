var http = require('http');
var pump = require('pump');
var protocol = require('hms-protocol');
var parse = require('hms/lib/parse-remote');
var path = require('path');
var proc = require('child_process');
var fs = require('fs');
var xtend = require('xtend');
var pingable = require('pingable');
var os = require('os');
var once = require('once');
var JSONStream = require('JSONStream');
var param = require('param');

process.stdout.setMaxListeners(0);
process.stderr.setMaxListeners(0);

var help = param('help');
if (help) {
	console.log("Helps stuff");
	process.exit(0);
}

var HANDSHAKE =
	'HTTP/1.1 101 Swiching Protocols\r\n'+
	'Upgrade: hms-protocol\r\n'+
	'Connection: Upgrade\r\n\r\n';

var POWERSHELL = path.join(__dirname, 'scripts');
var PS_SYS_NATIVE = 'c:\\windows\\sysnative\\windowspowershell\\v1.0\\powershell.exe';
var PS_SYS_32 = 'c:\\windows\\system32\\windowspowershell\\v1.0\\powershell.exe';

var PS = fs.existsSync(PS_SYS_NATIVE) ? PS_SYS_NATIVE : PS_SYS_32;
if (!fs.existsSync(PS)) throw new Error('powershell not found');

var ssh_key = param('i');
var tags = ['windows'].concat(param('tag') || []);

var remote = parse(param('terminal') || process.argv[2] || 'localhost:10002', {key:ssh_key});
var origin = os.hostname();
var debug = param('debug');
if (debug) console.log("Using remote:", remote);

var server = http.createServer(function(request, response) {
	response.end('hms-windows-dock\n');
});

var tarServer = http.createServer(function(request, response) {
	if (debug) console.log('Fetching tar: ', request.url);
	var req = http.request(xtend(remote, {
		method:'GET',
		path:request.url,
		headers:{origin:origin}
	}));

	req.on('response', function(res) {
		response.writeHead(res.statusCode, res.headers);
		pump(res, response);
	});
	req.on('error', function() {
		response.destroy();
	});
	req.end();
});
tarServer.listen(7001);

var ps = function(file, opts, cb) {
	var params = ['-ExecutionPolicy', 'remotesigned', '-File', path.join(POWERSHELL, file+'.ps1')];

	Object.keys(opts).forEach(function(key) {
		params.push('-'+key, opts[key]);
	});
	if (debug) console.log("Spawning ",PS, params);
	var ch = proc.spawn(PS, params);

	cb = once(cb);
	if (debug) ch.stdout.pipe(process.stdout);
	ch.stderr.pipe(process.stderr);
	ch.stdout.pipe(JSONStream.parse()).once('data', function(data) {
		cb(null, data);
	});

	ch.on('error', cb);
	ch.on('close', function(code) {
		if (!code ){
			return cb();
		}
		return cb(new Error('Stream closed without data'));
	});
};

var dropped = true;
var connect = function() {
	var payload = xtend(remote, {
		method:'CONNECT',
		path:'/dock',
		headers:{origin:origin}
	})
	if (debug) console.log("Connect:", payload);
	var req = http.request(payload);

	var reconnect = once(function() {
		console.log("Reconnect");
		if (dropped) return setTimeout(connect, 5000);
		dropped = true;
		return setTimeout(connect, 2500);
	});

	req.on('error', function(err) {
		console.log("Error:",err);
		reconnect();
	});
	req.on('connect', function(res, socket, data) {
		dropped = false;

		var peer = protocol();
		onpeer(peer);
		var payload = {
			id: origin,
			type: 'dock',
			tags: tags
		}
		if (debug) console.log("Handshake:", payload);
		peer.handshake(payload);

		pump(socket, peer, socket, reconnect);
		peer.write(data);
	});

	req.end();
};

connect();

var onpeer = function(peer) {
	pingable(peer);

	peer.on('add', function(id, opts, cb) {
		ps('add', {
			serviceName: id
		}, cb);
	});

	peer.on('remove', function(id, cb) {
		ps('remove', {
			serviceName: id
		}, cb);
	});

	peer.on('sync', function(id, service, cb) {
		ps('sync', {
			serviceName: id,
			fetchTar: path.join(__dirname, 'fetch-tar.js'),
			tarball: "http://localhost:7001/" + id
		}, cb);
	});

	peer.on('update', function(id, service, cb) { // do nothing right now
		cb();
	});

	peer.on('restart', function(id, cb) {
		ps('restart', {
			serviceName: id
		}, cb);
	});

	peer.on('start', function(id, cb) {
		ps('restart', {
			serviceName: id
		}, cb);
	});

	peer.on('stop', function(id, cb) {
		ps('stop', {
			serviceName: id
		}, cb);
	});

	peer.on('list', function(cb) {
		ps('list', {}, function(err, data) {
			if (err) {
				return cb(err, null);
			}
			return cb(null, [].concat(data || []));
		});
	});

	peer.on('ps', function(cb) {
		ps('ps', {}, function(err, data) {
			if (err) {
				return cb(err, null);
			}

			return cb(null, [{ id: origin, list: [].concat(data || [])}]);
		});
	});
};

server.on('connect', function(request, socket, data) {
	var peer = protocol();
	socket.write(HANDSHAKE);
	pump(socket, peer, socket);
	peer.write(data);
	peer.on('handshake', function(handshake) {
		onpeer(peer);
	});
});

server.listen(10002);
