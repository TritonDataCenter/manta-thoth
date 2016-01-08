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
ThothBatchStream(opts)
{
	var self = this;

	/*
	 * Check for valid input options:
	 */
	mod_assert.equal(typeof (opts), 'object');

	mod_assert.equal(typeof (opts.batchSize), 'number');
	mod_assert.ok(!isNaN(opts.batchSize) && opts.batchSize > 0);
	self.tbs_batchSize = opts.batchSize;

	mod_stream.Transform.call(self, {
		objectMode: true,
		highWaterMark: 0
	});

	self.tbs_accum = [];
}
mod_util.inherits(ThothBatchStream, mod_stream.Transform);

ThothBatchStream.prototype._transform = function
_transform(obj, _, done)
{
	var self = this;

	/*
	 * Accumulate the incoming object.
	 */
	self.tbs_accum.push(obj);

	if (self.tbs_accum.length < self.tbs_batchSize) {
		/*
		 * We have not accumulated an entire batch, so request
		 * more objects immediately.
		 */
		done();
		return;
	}

	/*
	 * Push the accumulated array along to the next stream in the
	 * pipeline.
	 */
	self.push(self.tbs_accum);
	self.tbs_accum = [];
	done();
};

ThothBatchStream.prototype._flush = function
_flush(done)
{
	var self = this;

	if (self.tbs_accum.length > 0) {
		/*
		 * If we accumulated less than a full batch, then we
		 * must push out one final undersized array now.
		 */
		self.push(self.tbs_accum);
	}
	done();
};

module.exports = function batchStream(batchSize) {
	return (new ThothBatchStream({
		batchSize: batchSize
	}));
};
