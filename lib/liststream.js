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
ThothListStream(opts)
{
	var self = this;

	/*
	 * Check for valid input options:
	 */
	mod_assert.equal(typeof (opts), 'object');
	mod_assert.equal(typeof (opts.manta), 'object');

	if (opts.type !== undefined) {
		mod_assert.equal(typeof (opts.type), 'string');
	}
	self.tls_type = opts.type || undefined;

	if (opts.time !== undefined) {
		mod_assert.equal(typeof (opts.time), 'boolean');
	}
	self.tls_time = opts.time || false;

	if (opts.reverse !== undefined) {
		mod_assert.equal(typeof (opts.reverse), 'boolean');
	}
	self.tls_reverse = opts.reverse || false;

	if (opts.filter !== undefined) {
		mod_assert.equal(typeof (opts.filter), 'function');
	}
	self.tls_filter = opts.filter || null;

	mod_assert.equal(typeof (opts.path), 'string');
	self.tls_path = opts.path;

	mod_stream.PassThrough.call(self, {
		objectMode: true,
		highWaterMark: 0
	});

	self.tls_scanComplete = false;

	/*
	 * Create a filtering transform stream that can arrest the flow of
	 * the stream after a specific object has passed through.
	 */
	self.tls_xform = new mod_stream.Transform({
		objectMode: true,
		highWaterMark: 0
	});
	self.tls_xform._transform = function (ent, _, next) {
		if (self.tls_scanComplete) {
			/*
			 * We are not interested in any more objects from the
			 * input stream, so drop this entry and return
			 * immediately.
			 */
			next();
			return;
		}

		if (self.tls_filter !== null) {
			/*
			 * The consumer has provided a filtering function.
			 * Check to see if this object should be included or
			 * not.
			 */
			var filter_result = self.tls_filter(ent, function stop() {
				/*
				 * The consumer has signalled that no more
				 * objects are required.
				 */
				self.stop();
			});
			mod_assert.equal(typeof (filter_result), 'boolean');

			if (!filter_result) {
				/*
				 * The consumer does not want this particular
				 * object.
				 */
				next();
				return;
			}
		}

		self.push(ent);
		next();
	};

	/*
	 * Create the list stream for the directory we were passed:
	 */
	self.tls_ls = opts.manta.createListStream(self.tls_path, {
		mtime: self.tls_time,
		reverse: self.tls_reverse,
		type: self.tls_type
	});
	self.tls_ls.on('error', function (err) {
		self.emit('error', err);
	});

	/*
	 * Pipe the list stream through our filter and back into ourselves, a
	 * passthrough stream, from which consumers will read() directory
	 * entries.
	 */
	self.tls_ls.pipe(self.tls_xform).pipe(self);
}
mod_util.inherits(ThothListStream, mod_stream.PassThrough);

/*
 * This function is called to tear down the stream once we have seen the last
 * object we are interested in.  The consumer may call it at any time, as well.
 */
ThothListStream.prototype.stop = function
stop()
{
	var self = this;

	if (self.tls_scanComplete) {
		return;
	}
	self.tls_scanComplete = true;

	if (self.tls_ls !== null) {
		/*
		 * Unpipe the Manta list stream:
		 */
		self.tls_ls.unpipe();
		self.tls_ls = null;
	}

	self.push(null);
};

module.exports = {
	ThothListStream: ThothListStream
};
