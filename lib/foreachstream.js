/*
 * Copyright 2016 Joyent, Inc.
 */

var mod_assert = require('assert');
var mod_util = require('util');

var mod_stream = require('stream');
if (!mod_stream.Readable) {
	/*
	 * If we're on node 0.8, pull in streams2 explicitly.
	 */
	mod_stream = require('readable-stream');
}

function
ThothForEachStream(opts)
{
	var self = this;

	/*
	 * Check for valid input options:
	 */
	mod_assert.equal(typeof (opts), 'object');

	mod_assert.equal(typeof (opts.workFunc), 'function');
	self.tfes_workFunc = opts.workFunc;

	mod_assert.equal(typeof (opts.endFunc), 'function');
	self.tfes_endFunc = opts.endFunc;

	mod_stream.Transform.call(self, {
		objectMode: true,
		highWaterMark: 0
	});

	self.tfes_count = 0;
	self.tfes_ended = false;

	var finalcb = function (err) {
		if (self.tfes_ended) {
			return;
		}
		self.tfes_ended = true;

		self.removeListener('finish', finalcb);
		self.removeListener('error', finalcb);

		self.tfes_endFunc(err, {
			count: self.tfes_count
		});
	};

	self.once('finish', finalcb);
	self.once('error', finalcb);
}
mod_util.inherits(ThothForEachStream, mod_stream.Transform);

ThothForEachStream.prototype._write = function
_write(obj, _, done)
{
	var self = this;

	self.tfes_workFunc(obj, function (err) {
		self.tfes_count++;
		done(err);
	});
};

module.exports = function forEachStream(workFunc, endFunc) {
	return (new ThothForEachStream({
		workFunc: workFunc,
		endFunc: endFunc
	}));
};
