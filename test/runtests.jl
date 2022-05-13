using Test, DebugLogging

module Test2

using Logging

function run()
    @debug "debug Test2"
    @info "info Test2"
end

end

module Test1

using DebugLogging

DebugLogging.@setup()

function run()
    @debug "debug Test1"
    @debug2 "debug2 Test1"
    @debug3 "debug3 Test1"
end

module SubTest1

using DebugLogging
DebugLogging.@setup()

function run()
    @debug "debug SubTest1"
    @debug2 "debug2 SubTest1"
    @debug3 "debug3 SubTest1"
end

end

end # module

using .Test2, .Test1
@test_logs (:info, "info Test2") Test2.run()
@test_logs Test1.run()
@test_logs (:debug, "debug Test1") min_level=Test1.Debug Test1.run()
Test1.setloglevel!(Debug)
Test1.run() # prints "debug Test1"
Test2.run() # only prints "info Test2"; debug printing not enabled for non-Test1 modules
Test1.SubTest1.run() # doesn't log
Test1.SubTest1.setloglevel!(Debug)
Test1.SubTest1.run() # logs "debug SubTest1"
