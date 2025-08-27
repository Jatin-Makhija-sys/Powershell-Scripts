$task  = Get-ScheduledTask -TaskPath '\Microsoft\Windows\CloudRestore\' -TaskName 'Backup'
$info  = $task | Get-ScheduledTaskInfo
$trigs = $task.Triggers | ForEach-Object {
  [pscustomobject]@{
    Type               = $_.TriggerType
    StartBoundary      = $_.StartBoundary
    Enabled            = $_.Enabled
    RepetitionInterval = $_.Repetition.Interval
    RepetitionDuration = $_.Repetition.Duration
    DaysOfWeek         = ($_.DaysOfWeek -join ',')
    DaysInterval       = $_.DaysInterval
    WeeksInterval      = $_.WeeksInterval
    RandomDelay        = $_.RandomDelay
  }
}

[pscustomobject]@{
  TaskName    = $task.TaskName
  NextRunTime = $info.NextRunTime
  LastRunTime = $info.LastRunTime
  LastResult  = $info.LastTaskResult
  Status      = $task.State
  Triggers    = $trigs
} | Format-List