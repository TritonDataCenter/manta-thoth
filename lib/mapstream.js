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
ThothMapStream(opts)
{
	var self = this;

	/*
	 * Check for valid input options:
	 */
	mod_assert.equal(typeof (opts), 'object');

	mod_assert.equal(typeof (opts.workFunc), 'function');
	self.tms_workFunc = opts.workFunc;

	mod_stream.Transform.call(self, {
                objectMode: true,
		highWaterMark: 0
	});

	self.tms_countIn = 0;
	self.tms_countOut = 0;
}
mod_util.inherits(ThothMapStream, mod_stream.Transform);

ThothMapStream.prototype._transform = function
_transform(obj, _, done)
{
	var self = this;

	var pushFunc = function (obj) {
		mod_assert.ok(obj !== null);
		self.tms_countOut++;
		self.push(obj);
	};

	self.tms_countIn++;
	self.tms_workFunc(obj, pushFunc, done);
};

module.exports = function mapStream(workFunc) {
	return (new ThothMapStream({
		workFunc: workFunc
	}));
};
