var tar = require('tar-fs');
var request = require('request');
var zlib = require('zlib');

var from = process.argv[2];
var to = process.argv[3];

if (!from || !to) {
	console.error('usage: node fetch-tar.js [from-url] [to-folder]');
	process.exit(1);
}

console.log('fetching tarball', from, to);

request(from)
	.pipe(zlib.createGunzip())
	.pipe(tar.extract(to))
	.on('finish', function() {
		console.log('tarball downloaded...')
	})