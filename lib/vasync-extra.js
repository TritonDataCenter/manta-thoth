/*
 * Copyright 2020 Joyent, Inc.
 */

var mod_vasync = require('vasync');

/*
 * vasync.forEachParallel(), but in args.batchSize batches.
 */
var forEachParallelBatched = function(args, cb)
{
    var batched = [];
    var inputs = args.inputs.slice(0);

    while (inputs.length != 0) {
        batched.push(inputs.splice(0, args.batchSize));
    }

    mod_vasync.forEachPipeline({
        func: function (batch, next) {
            mod_vasync.forEachParallel({
                func: args.func,
                inputs: batch
            }, next);
        },
        inputs: batched
    }, cb);
}

module.exports = {
    forEachParallelBatched: forEachParallelBatched
};
