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

var HANDSHAKE =
	'HTTP/1.1 101 Swiching Protocols\r\n'+
	'Upgrade: hms-protocol\r\n'+
	'Connection: Upgrade\r\n\r\n';

var POWERSHELL = path.join(__dirname, 'scripts');
var PS_SYS_NATIVE = 'c:\\windows\\sysnative\\windowspowershell\\v1.0\\powershell.exe';
var PS_SYS_32 = 'c:\\windows\\system32\\windowspowershell\\v1.0\\powershell.exe'

var PS = fs.existsSync(PS_SYS_NATIVE) ? PS_SYS_NATIVE : PS_SYS_32;
if (!fs.existsSync(PS)) throw new Error('powershell not found');

var remote = parse(process.argv[2] || 'localhost:10002');
var origin = "win-" + os.hostname();

var server = http.createServer(function(request, response) {
	response.end('hms-windows-dock\n');
});

var tarServer = http.createServer(function(request, response) {
	console.log('fetching tar: ', request.url)
	var req = http.request(xtend(remote, {
		method:'GET',
		path:request.url,
		headers:{origin:origin}
	}));	

	req.on('response', function(res) {
		response.writeHead(res.statusCode, res.headers);
		pump(res, response)
	});
	req.on('error', function() {
		response.destroy();
	});
	req.end();
});
tarServer.listen(7001);

var ps = function(file, opts, cb) {
	var params = [];

	Object.keys(opts).forEach(function(key) {
		params.push('-'+key, opts[key]);
	});

	var ch = proc.spawn(PS, ['-ExecutionPolicy', 'remotesigned', '-File', path.join(POWERSHELL, file+'.ps1')].concat(params));
	
	cb = once(cb);
	ch.stdout.pipe(JSONStream.parse()).once('data', function(data) {
		cb(null, data);
	});

	ch.on('error', cb);
	ch.on('close', function(code) {
		if (!code) {
			return cb();
		}		
		cb(new Error('Stream closed without data'));
	});
};

var dropped = true;
var connect = function() {
	var req = http.request(xtend(remote, {
		method:'CONNECT',
		path:'/dock',
		headers:{origin:origin}
	}));

	var reconnect = once(function() {
		if (dropped) return setTimeout(connect, 5000);
		dropped = true;
		setTimeout(connect, 2500);
	});

	req.on('error', reconnect);
	req.on('connect', function(res, socket, data) {
		dropped = false;

		var peer = protocol();
		onpeer(peer);
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
		}, cb)
	});

	peer.on('update', function(id, service, cb) { // do nothing right now
		cb();
	});

	peer.on('restart', function(id, cb) {
		ps('restart', {
			serviceName: id
		}, cb)
	});

	peer.on('list', function(cb) {
		ps('list', {}, function(err, data) {
			if (err) {
				return cb(err, null);
			}
			cb(null, data || []);
		});
	});

	peer.on('ps', function(cb) {
		ps('ps', {}, function(err, data) {			
			if (err) {
				return cb(err, null);
			}
			
			cb(null, [{ id: origin, list: data || []}])
		});
	});
};

server.on('connect', function(request, socket, data) {
	var peer = protocol();
	onpeer(peer);
	socket.write(HANDSHAKE);
	pump(socket, peer, socket);
	peer.write(data);
});

server.listen(10002);