-- dim_time: a RELATIVE time dimension derived from PaySim's `step`
-- (hours since the simulation began, 1..743).
--
-- PaySim has NO real calendar dates, so this supports ELAPSED-TIME analysis
-- only: velocity, hour-of-day patterns, activity trends across the run.
-- Do NOT use it for day-of-week / holiday / seasonal features - those would be
-- meaningless on synthetic timestamps. (Documented limitation, on purpose.)

with steps as (

    select distinct step_hour
    from {{ ref('stg_transactions') }}

)

select
    step_hour,                                   -- key: hours since sim start
    DIV(step_hour - 1, 24) + 1 as day_number,    -- synthetic "day" (DIV = integer division)
    MOD(step_hour - 1, 24)     as hour_of_day     -- 0..23 position within the day
from steps
