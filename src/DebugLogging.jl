module DebugLogging

using Logging

import Base.CoreLogging: _min_enabled_level

# re-export Logging exports
export Logging, AbstractLogger, LogLevel, NullLogger,
    @debug, @info, @warn, @error, @logmsg,
    with_logger, current_logger, global_logger, disable_logging,
    SimpleLogger, ConsoleLogger, Debug

export @debug2, @debug3, @debug4, Debug2, Debug3, Debug4, ModuleFilterLogger

const Debug2 = Debug - 1
const Debug3 = Debug - 2
const Debug4 = Debug - 3

macro debug2(exs...); :(@logmsg Debug2 $(exs...)); end
macro debug3(exs...); :(@logmsg Debug3 $(exs...)); end
macro debug4(exs...); :(@logmsg Debug4 $(exs...)); end

struct ModuleFilterLogger{T <: AbstractLogger} <: AbstractLogger
    mod::Module
    level::LogLevel
    logger::T
end

Logging.handle_message(x::ModuleFilterLogger, args...; kw...) = 
    Logging.handle_message(x.logger, args...; kw...)

function Logging.shouldlog(x::ModuleFilterLogger, level, _module, args...; kw...)
    if x.mod == _module
        # i.e. this logger will handle ALL log filtering for a specific module
        return level >= x.level
    end
    # why the call to min_enabled_level here for child logger?
    # we're basically bypassing the core logging min_enabled_level check by
    # passing the min level of any loggers because we want to do the level check
    # *here* for the module-specific logger, but then also need to do the level check
    # for other loggers
    return level >= Logging.min_enabled_level(x.logger) && Logging.shouldlog(x.logger, level, _module, args...; kw...)
end

# we want the minimum of our module-specific level and any other loggers
Logging.min_enabled_level(x::ModuleFilterLogger, args...; kw...) =
    min(x.level, Logging.min_enabled_level(x.logger, args...; kw...))

Logging.catch_exceptions(x::ModuleFilterLogger, args...; kw...) = 
    Logging.catch_exceptions(x.logger, args...; kw...)

function setloglevel!(mod::Module, level)
    _min_enabled_level[] = min(level, _min_enabled_level[])
    logger = global_logger()
    if logger isa ModuleFilterLogger
        if logger.mod == mod
            logger = logger.logger
        end
    end
    global_logger(ModuleFilterLogger(mod, level, logger))
    return
end

function withloglevel(@nospecialize(f), mod::Module, level)
    old_min_enabled_level = _min_enabled_level[]
    _min_enabled_level[] = min(level, _min_enabled_level[])
    try
        with_logger(ModuleFilterLogger(mod, level, current_logger())) do
            f()
        end
    finally
        _min_enabled_level[] = old_min_enabled_level
    end
end

macro setup()
    esc(quote
        setloglevel!(level) = DebugLogging.setloglevel!(@__MODULE__, level)
        withloglevel(f, level) = DebugLogging.withloglevel(f, @__MODULE__, level)
    end)
end

end # module DebugLogging
