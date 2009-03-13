
module ProjectLeveling

  # Task assignment manager
  class TaskAssignmentManager
  
    # Assign a possible solution to the current assignment
    #
    # Parameters:
    # * *iTask* (_Task_): The Task being applied
    # * *iTasksListToIgnore* (<em>list<Task></em>): The tasks list we have to ignore due to a recursive call
    # * *iPossibleSolution* (<em>TaskAssignmentSolution_Type</em>): The possible solution
    # * *iPossibleSolutionMeasures* (<em>map<AssignmentStrategy,[Integer,Integer]></em>): The measures associated to the possible solution
    # * *iMinimalPathImportance* (_Integer_): The current path's minimal importance, used to update the non optimal delays of the assignment info
    # * *ioAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The assignment info to modify
    # * *ioConsequences* (<em>ShiftedTaskConsequences_Type</em>): The consequences to fill.
    # * *iAssignmentStrategies* (<em>list<AssignmentStrategy></em>): The list of assignment strategies to consider
    def self.assignPossibleSolution(iTask, iTasksListToIgnore, iPossibleSolution, iPossibleSolutionMeasures, iMinimalPathImportance, ioAssignmentInfo, ioConsequences, iAssignmentStrategies)
      # 1.
      lDelay = (iPossibleSolution.EndDate - ioAssignmentInfo[iTask].MinEndDate)
      # 2.
      ioAssignmentInfo[iTask].MinStartDate = iPossibleSolution.StartDate
      ioAssignmentInfo[iTask].MinEndDate = iPossibleSolution.EndDate
      ioAssignmentInfo[iTask].MinEndDateHours = iPossibleSolution.EndDateHours
      # 3.
      if (lDelay > 0)
        # 3.1.
        TaskAssignmentManager.notifyMinimalEndDateChanged(iTask, lDelay, ioAssignmentInfo, iTasksListToIgnore, iMinimalPathImportance, ioConsequences, iAssignmentStrategies)
        # 3.2.
        if (!ioConsequences.PossibleConsequence)
          # 3.2.1.
          return
        end
      end
      # 4.
      TaskAssignmentManager.removeResourcesFromOtherTasks(iPossibleSolution, [iTask], iMinimalPathImportance, ioAssignmentInfo, ioConsequences, iAssignmentStrategies)
      # 5.
      if (!ioConsequences.PossibleConsequence)
        # 5.1.
        return
      end
      # 6.
      ioAssignmentInfo[iTask].FinalAssignment = iPossibleSolution
      ioAssignmentInfo[iTask].FinalAssignmentMeasures = iPossibleSolutionMeasures
    end
    
    # Shift a task' successors based on a new date
    #
    # Parameters:
    # * *iTask* (_Task_): The task that contains all children tasks to shift
    # * *iMinStartDate* (_Date_): The minimal start date for the children tasks
    # * *iTasksListToIgnore* (<em>list<Task></em>): The tasks list we have to ignore due to a recursive call [default to an empty list]
    # * *iMinimalPathImportance* (_Integer_): The minimal importance of already assigned tasks.
    # * *ioAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The current availability of resources to modify
    # * *ioConsequences* (<em>ShiftedTaskConsequences_Type</em>): The consequences to fill.    
    # * *iAssignmentStrategies* (<em>list<AssignmentStrategy></em>): The list of assignment strategies to consider
    def self.shiftChildrenTasks(iTask, iMinStartDate, iTasksListToIgnore, iMinimalPathImportance, ioAssignmentInfo, ioConsequences, iAssignmentStrategies)
      if ($Debug)
        puts "Shifting successors of #{iTask.Name}: they can't start before #{iMinStartDate}."
      end
      # 1.
      iTask.Successors.each do |iChildTask|
        if (!iTasksListToIgnore.include?(iChildTask))
          # 1.1.
          if (ioAssignmentInfo[iChildTask].MinStartDate < iMinStartDate)
            # 1.1.1.
            if (ioAssignmentInfo[iChildTask].FinalAssignment != nil)
              if ($Debug)
                puts "Successor #{iChildTask.Name} was already validated with a start date on #{ioAssignmentInfo[iChildTask].MinStartDate}. Impossible to shift."
              end
              # 1.1.1.1.
              ioConsequences.addImpossibleSubShiftedTask(iChildTask)
              # 1.1.1.2.
              return
            # 1.1.2.
            else
              # 1.1.2.1.
              lFoundDay = false
              lChildStartDate = iMinStartDate
              while (!lFoundDay)
                # Is there an available resource for iChildTask on day lChildStartDate ?
                if (ioAssignmentInfo[iChildTask].AvailableResourcesSlots[lChildStartDate] != nil)
                  lFoundDay = true
                else
                  lChildStartDate += 1
                end
              end
              # 1.1.2.2.
              if (lFoundDay)
                if ($Debug)
                  puts "Successor #{iChildTask.Name} can be shifted from [#{ioAssignmentInfo[iChildTask].MinStartDate}..#{ioAssignmentInfo[iChildTask].MinEndDate}(#{ioAssignmentInfo[iChildTask].MinEndDateHours})] to [#{lChildStartDate}..?]."
                end
                # 1.1.2.2.1.
                lSuccess, lDelay = TaskAssignmentManager.shiftTaskMinimalDates(iChildTask, lChildStartDate, ioAssignmentInfo)
                # 1.1.2.2.2.
                if (!lSuccess)
                  if ($Debug)
                    puts "Successor #{iChildTask.Name}'s start date can not be shifted to #{lChildStartDate}. Impossible to find a correct minimal end date."
                  end
                  # 1.1.2.2.2.1.
                  ioConsequences.addImpossibleSubShiftedTask(iChildTask)
                  # 1.1.2.2.2.2.
                  return
                # 1.1.2.2.3.
                else
                  # 1.1.2.2.3.1.
                  ioConsequences.ShiftedTasks[iChildTask] = PathsManager::ShiftedTaskConsequences_Type.new
                  # 1.1.2.2.3.2.
                  TaskAssignmentManager.notifyMinimalEndDateChanged(iChildTask, lDelay, ioAssignmentInfo, iTasksListToIgnore, iMinimalPathImportance, ioConsequences.ShiftedTasks[iChildTask], iAssignmentStrategies)
                  # 1.1.2.2.3.3.
                  if (!ioConsequences.ShiftedTasks[iChildTask].PossibleConsequence)
                    # 1.1.2.2.3.3.1.
                    return
                  end
                end
              # 1.1.2.3.
              else
                if ($Debug)
                  puts "Successor #{iChildTask.Name}'s start date can not be shifted after #{ioAssignmentInfo[iChildTask].MinStartDate}."
                end
                # 1.1.2.3.1.
                ioConsequences.addImpossibleSubShiftedTask(iChildTask)
                # 1.1.2.3.2.
                return
              end
            end
          end
        end
      end
    end

    # Shift minimal dates of a task
    #
    # Parameters:
    # * *iTask* (_Task_): The task to shift
    # * *iMinStartDate* (_Date_): The new minimal start date
    # * *ioAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The current availability of resources to modify
    # Return:
    # * _Boolean_: Is it possible to perform such a shift ?
    # * _Integer_: The delay of the minimal end date.
    def self.shiftTaskMinimalDates(iTask, iMinStartDate, ioAssignmentInfo)
      lTaskAssignmentInfo = ioAssignmentInfo[iTask]
      # 1.
      lNumberOfAvailableHours = 0
      lNewMinEndDate = nil
      lNewMinEndDateHours = nil
      # 2.
      if (iMinStartDate <= lTaskAssignmentInfo.MinEndDate)
        if ($Debug)
          puts "--- Count the number of used hours we skip on task #{iTask.Name} from #{lTaskAssignmentInfo.MinStartDate} to #{iMinStartDate - 1}."
        end
        # 2.1.
        lHoursToAddAtTheEnd = 0
        # 2.2.
        (lTaskAssignmentInfo.MinStartDate .. iMinStartDate-1).each do |iDay|
          # 2.2.1.
          lTaskAssignmentInfo.AvailableResourcesSlots[iDay].each do |iResource, iWorkingHours|
            if ($Debug)
              puts "--- #{iWorkingHours} hours were used by resource #{iResource.Name} on day #{iDay}."
            end
            # 2.2.1.1.
            # 2.2.1.2.
            lNumberOfAvailableHours += TaskAssignmentManager.removeCountedHoursFromResourcesBuffers(lTaskAssignmentInfo.ResourcesBuffers[iResource], iWorkingHours)
          end
        end
        if ($Debug)
          puts "--- A total of #{lNumberOfAvailableHours} hours were used. Now they will not be available anymore to #{iTask.Name}."
        end
        # 2.3.
        lNewMinEndDate, lNewMinEndDateHours = TaskAssignmentManager.computeShiftedDateHours(iTask, lTaskAssignmentInfo.MinEndDate, lTaskAssignmentInfo.MinEndDateHours, lHoursToAddAtTheEnd, ioAssignmentInfo)
      # 3.
      else
        # 3.1.
        (lTaskAssignmentInfo.MinStartDate .. iMinStartDate-1).each do |iDay|
          # 3.1.1.
          lTaskAssignmentInfo.AvailableResourcesSlots[iDay].each do |iResource, iWorkingHours|
            # 3.1.1.1.
            lNumberOfAvailableHours += iWorkingHours
          end
        end
        # 3.2.
        lTaskAssignmentInfo.ResourcesBuffers.each do |iResource, iBufferInfo|
          # 3.2.1.
          iBufferInfo.Used = 0
          iBufferInfo.Unused = 0
        end
        # 3.3.
        lNewMinEndDate, lNewMinEndDateHours = TaskAssignmentManager.computeShiftedDateHours(iTask, iMinStartDate, 0, iTask.Sizing, ioAssignmentInfo)
      end
      # 4.
      if (lNewMinEndDate == nil)
        # 4.1.
        return false, nil
      # 5.
      else
        # 5.1.
        lMinimalEndDateDelay = (lNewMinEndDate - ioAssignmentInfo[iTask].MinEndDate)
        # 5.2.
        lTaskAssignmentInfo.MinStartDate = iMinStartDate
        lTaskAssignmentInfo.MinEndDate = lNewMinEndDate
        lTaskAssignmentInfo.MinEndDateHours = lNewMinEndDateHours
        # 5.3.
        lTaskAssignmentInfo.AvailableHours -= lNumberOfAvailableHours
        # 5.4.
        return true, lMinimalEndDateDelay
      end
    end
    
    # Simple function computing a shift date.
    #
    # Parameters:
    # * *iTask* (_Task_): The task for which the shift is computed
    # * *iDate* (_Date_): The initial date
    # * *iDateHours* (_Integer_): The number of hours to count from in the initial date
    # * *iHoursShift* (_Integer_): The number of hours to count from iDate and iDateHours
    # * *iAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The current availability of resources
    # Return:
    # * _Date_: The new date
    # * _Integer_: The number of hours within the date
    def self.computeShiftedDateHours(iTask, iDate, iDateHours, iHoursShift, iAssignmentInfo)
      if ($Debug)
        puts "-- Shift date #{iDate}(#{iDateHours}) for task #{iTask.Name} of #{iHoursShift} hours."
      end
      lTaskAssignmentInfo = iAssignmentInfo[iTask]
      # 1.
      lTotalUsedHoursLastDay = 0
      lHoursToIgnoreFirstDay = iDateHours
      rNewDate = nil
      rNewDateHours = nil
      # 2.
      (iDate .. lTaskAssignmentInfo.MaxEndDate).each do |iDay|
        # 2.1.
        lUsedHoursDay = 0
        # 2.2.
        # Check first if there is something on day iDay
        if (lTaskAssignmentInfo.AvailableResourcesSlots[iDay] != nil)
          lTaskAssignmentInfo.AvailableResourcesSlots[iDay].each do |iResource, iWorkingHours|
            if ($Debug)
              puts "-- In current assignment, resource #{iResource.Name} has #{lTaskAssignmentInfo.ResourcesBuffers[iResource].Used} hours used, and #{lTaskAssignmentInfo.ResourcesBuffers[iResource].Unused} hours still free to be used inside the minimal dates."
            end
            # 2.2.1.
            lUseableHours = nil
            if (iWorkingHours + lTaskAssignmentInfo.ResourcesBuffers[iResource].Used <= iTask.ResourcesMap[iResource])
              # 2.2.1.1.
              lUseableHours = iWorkingHours
            # 2.2.2.
            else
              # 2.2.2.1.
              lUseableHours = iTask.ResourcesMap[iResource] - lTaskAssignmentInfo.ResourcesBuffers[iResource].Used
            end
            # 2.2.3.
            if (iDay == iDate)
              # 2.2.3.1.
              if (lUseableHours > lHoursToIgnoreFirstDay)
                # 2.2.3.1.1.
                lUseableHours -= lHoursToIgnoreFirstDay
                # 2.2.3.1.2
                lHoursToIgnoreFirstDay = 0
              # 2.2.3.2.
              else
                # 2.2.3.2.1.
                lUseableHours = 0
                # 2.2.3.2.2.
                lHoursToIgnoreFirstDay -= lUseableHours
              end
            end
            # 2.2.4.
            if (lUseableHours > 0)
              if ($Debug)
                puts "-- We can use #{lUseableHours} hours on day #{iDay} from resource #{iResource.Name}"
              end
              # 2.2.4.1.
              if (lTotalUsedHoursLastDay + lUsedHoursDay + lUseableHours >= iHoursShift)
                if ($Debug)
                  puts "-- We have reached the total number of hours on day #{iDay}, using #{iHoursShift - lTotalUsedHoursLastDay} hours."
                end
                # 2.2.4.1.1.
                rNewDate = iDay
                # 2.2.4.1.2.
                rNewDateHours = iHoursShift - lTotalUsedHoursLastDay
                # 2.2.4.1.3.
                lTaskAssignmentInfo.ResourcesBuffers[iResource].Used += iHoursShift - lTotalUsedHoursLastDay - lUsedHoursDay
                # 2.2.4.1.4.
                break
              # 2.2.4.2.
              else
                # 2.2.4.2.1.
                lUsedHoursDay += lUseableHours
                # 2.2.4.2.2.
                lTaskAssignmentInfo.ResourcesBuffers[iResource].Used += lUseableHours
                if ($Debug)
                  puts "-- We have not yet reached the total number of hours on day #{iDay}. Use #{lUseableHours} hours from resource #{iResource.Name}, which has now #{lTaskAssignmentInfo.ResourcesBuffers[iResource].Used} hours used."
                end
              end
            end
            if ($Debug)
              puts "-- In new assignment, resource #{iResource.Name} has #{lTaskAssignmentInfo.ResourcesBuffers[iResource].Used} hours used, and #{lTaskAssignmentInfo.ResourcesBuffers[iResource].Unused} hours still free to be used inside the minimal dates."
            end
          end
          if (rNewDate != nil)
            break
          end
          # 2.3.
          lTotalUsedHoursLastDay += lUsedHoursDay
        end
      end
      # 3.
      if (rNewDate == nil)
        if ($Debug)
          puts "-- Date #{iDate}(#{iDateHours}) for task #{iTask.Name} shifted of #{iHoursShift} hours is impossible to get."
        end
        # 3.1.
        return nil, nil
      # 4.
      else
        if ($Debug)
          puts "-- Date #{iDate}(#{iDateHours}) for task #{iTask.Name} shifted of #{iHoursShift} hours is #{rNewDate}(#{rNewDateHours})."
        end
        # 4.1.
        return rNewDate, rNewDateHours
      end
    end

    # Remove hours present in the minimal schedule
    #
    # Parameters:
    # * *ioResourceBuffer* (<em>ResourceBuffers_Type</em>): The resource buffers to update
    # * *iHours* (_Integer_): The number of hours we delete from the buffers
    # Return:
    # * _Integer_: The number of hours effectively removed from the used buffer
    def self.removeCountedHoursFromResourcesBuffers(ioResourceBuffer, iHours)
      # 1.
      rRemovedHoursFromUsedBuffer = 0
      # 2.
      if (ioResourceBuffer.Unused >= iHours)
        # 2.1.
        ioResourceBuffer.Unused -= iHours
      # 3.
      else
        # 3.1.
        rRemovedHoursFromUsedBuffer = iHours - ioResourceBuffer.Unused
        # 3.2.
        ioResourceBuffer.Unused = 0
        # 3.3.
        if (ioResourceBuffer.Used < rRemovedHoursFromUsedBuffer)
          # 3.3.1.
          rRemovedHoursFromUsedBuffer = ioResourceBuffer.Used
        end
        # 3.4.
        ioResourceBuffer.Used -= rRemovedHoursFromUsedBuffer
      end
      # 4.
      return rRemovedHoursFromUsedBuffer
    end
    
    # Remove chosen resources from other tasks
    #
    # Parameters:
    # * *iResources* (<em>map<Date,map<Resource,Integer>></em>): The resources we want to remove from the tasks' available resources' lists. For each day, for each resource, the number of hours to remove.
    # * *iTasksListToIgnore* (<em>list<Task></em>): The tasks list we have to ignore due to a recursive call [default to an empty list]
    # * *iMinimalPathImportance* (_Integer_): The minimal importance of already assigned tasks.
    # * *ioAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The current availability of resources to modify
    # * *ioConsequences* (<em>ShiftedTaskConsequences_Type</em>): The consequences to fill.
    # * *iAssignmentStrategies* (<em>list<AssignmentStrategy></em>): The list of assignment strategies to consider
    def self.removeResourcesFromOtherTasks(iResources, iTasksListToIgnore, iMinimalPathImportance, ioAssignmentInfo, ioConsequences, iAssignmentStrategies)
      # 1.
      ioAssignmentInfo.each do |iOtherTask, iOtherAssignmentInfo|
        if ((!iTasksListToIgnore.include?(iOtherTask)) and
            (iOtherAssignmentInfo.FinalAssignment == nil))
          # 1.1.
          lTotalRemovedHoursFromUsedBuffers = 0
          lDatesToRecalculate = false
          lStartDateToShift = false
          # 1.2.
          iResources.each do |iDay, iDayResources|
            if (iDay >= iOtherAssignmentInfo.MinStartDate)
              # 1.2.1.
              # 1.2.1.1.
              # 1.2.1.2.
              # 1.2.1.2.1.
              # 1.2.1.3.
              # 1.2.1.3.1.
              # 1.2.1.4.
              # 1.2.1.4.1.
              # 1.2.1.5.
              # 1.2.1.5.1.
              # 1.2.2.
              # 1.2.2.1.
              # 1.2.2.2.
              # 1.2.2.3.
              lDayOnStart = (iDay == iOtherAssignmentInfo.MinStartDate)
              lDayOnEnd = (iDay == iOtherAssignmentInfo.MinEndDate)
              lDayInBetween = ((iDay >= iOtherAssignmentInfo.MinStartDate) and
                               (iDay <= iOtherAssignmentInfo.MinEndDate))
              # 1.2.3.
              if (iOtherAssignmentInfo.AvailableResourcesSlots.has_key?(iDay))
                iDayResources.each do |iResource, iWorkingHours|
                  # 1.2.3.1.
                  if (iOtherAssignmentInfo.AvailableResourcesSlots[iDay].has_key?(iResource))
                    # 1.2.3.1.1.
                    if ($Debug)
                      puts "Remove #{iWorkingHours} hours of resource #{iResource.Name} for task #{iOtherTask.Name} on day #{iDay}."
                    end
                    iOtherAssignmentInfo.AvailableResourcesSlots[iDay][iResource] -= iWorkingHours
                    if (iOtherAssignmentInfo.AvailableResourcesSlots[iDay][iResource] == 0)
                      iOtherAssignmentInfo.AvailableResourcesSlots[iDay].delete(iResource)
                      if (iOtherAssignmentInfo.AvailableResourcesSlots[iDay].empty?)
                        iOtherAssignmentInfo.AvailableResourcesSlots.delete(iDay)
                      end
                    end
                    # 1.2.3.1.2.
                    iOtherAssignmentInfo.AvailableHours -= iWorkingHours
                    # 1.2.3.1.3.
                    if (lDayInBetween)
                      # 1.2.3.1.3.1.
                      lDatesToRecalculate = true
                      lUsedHoursRemoved = iWorkingHours
                      # 1.2.3.1.3.2.
                      if (lDayOnEnd)
                        # 1.2.3.1.3.2.1.
                        if (iWorkingHours > iOtherAssignmentInfo.MinEndDateHours)
                          lUsedHoursRemoved = iOtherAssignmentInfo.MinEndDateHours
                        end
                      # 1.2.3.1.3.3.
                      # 1.2.3.1.3.3.1.
                      end
                      # 1.2.3.1.3.4.
                      # 1.2.3.1.3.5.
                      lTotalRemovedHoursFromUsedBuffers += TaskAssignmentManager.removeCountedHoursFromResourcesBuffers(iOtherAssignmentInfo.ResourcesBuffers[iResource], lUsedHoursRemoved)
                    end
                  end
                end
                # 1.2.4.
                if ((lDayOnStart) and
                    (!iOtherAssignmentInfo.AvailableResourcesSlots.has_key?(iDay)))
                  # 1.2.4.1.
                  lStartDateToShift = true
                end
              end
            end
          end
          # 1.3.
          if (lDatesToRecalculate)
            # 1.3.1.
            lMinEndDateDelay = 0
            lShiftFromEndDate = true
            # 1.3.2.
            if (lStartDateToShift)
              if ($Debug)
                puts "We have to recalculate minimal start date of task #{iOtherTask.Name}. Current one (#{iOtherAssignmentInfo.MinStartDate}) does not have resources anymore."
              end
              # 1.3.2.1.
              (iOtherAssignmentInfo.MinStartDate .. iOtherAssignmentInfo.MaxEndDate).each do |iNextStartDay|
                if (iOtherAssignmentInfo.AvailableResourcesSlots.has_key?(iNextStartDay))
                  iOtherAssignmentInfo.MinStartDate = iNextStartDay
                  if ($Debug)
                    puts "New minimal start date found for task #{iOtherTask.Name}: #{iNextStartDay}"
                  end
                  break
                end
              end
              # 1.3.2.2.
              if (iOtherAssignmentInfo.MinStartDate > iOtherAssignmentInfo.MinEndDate)
                # 1.3.2.2.1.
                iOtherAssignmentInfo.ResourcesBuffers.each do |iResource, iBufferInfo|
                  # 1.3.2.2.1.1.
                  iBufferInfo.Used = 0
                  iBufferInfo.Unused = 0
                end
                # 1.3.2.2.2.
                lNewMinEndDate, lNewMinEndDateHours = TaskAssignmentManager.computeShiftedDateHours(iOtherTask, iOtherAssignmentInfo.MinStartDate, 0, iOtherTask.Sizing, ioAssignmentInfo)
                # 1.3.2.2.3.
                if (lNewMinEndDate == nil)
                  # 1.3.2.2.3.1.
                  ioConsequences.addImpossibleSubShiftedTask(iOtherTask)
                  # 1.3.2.2.3.2.
                  return
                # 1.3.2.2.4.
                else
                  # 1.3.2.2.4.1.
                  lMinEndDateDelay = (lNewMinEndDate - iOtherAssignmentInfo.MinEndDate)
                  # 1.3.2.2.4.2.
                  iOtherAssignmentInfo.MinEndDate = lNewMinEndDate
                  iOtherAssignmentInfo.MinEndDateHours = lNewMinEndDateHours
                  # 1.3.2.2.4.3.
                  lShiftFromEndDate = false
                end
              end
            end
            # 1.3.3.
            if ((lShiftFromEndDate) and
                (lTotalRemovedHoursFromUsedBuffers > 0))
              # 1.3.3.1.
              lNewMinEndDate, lNewMinEndDateHours = TaskAssignmentManager.computeShiftedDateHours(iOtherTask, iOtherAssignmentInfo.MinEndDate, iOtherAssignmentInfo.MinEndDateHours, lTotalRemovedHoursFromUsedBuffers, ioAssignmentInfo)
              # 1.3.3.2.
              if (lNewMinEndDate == nil)
                # 1.3.3.2.1.
                ioConsequences.addImpossibleSubShiftedTask(iOtherTask)
                # 1.3.3.2.2.
                return
              # 1.3.3.3.
              else
                # 1.3.3.3.1.
                lMinEndDateDelay = (lNewMinEndDate - iOtherAssignmentInfo.MinEndDate)
                # 1.3.3.3.2.
                iOtherAssignmentInfo.MinEndDate = lNewMinEndDate
                iOtherAssignmentInfo.MinEndDateHours = lNewMinEndDateHours
              end
            end
            # 1.3.4.
            if (lMinEndDateDelay > 0)
              if ($Debug)
                puts "Minimal end date has changed (shift of #{lMinEndDateDelay} days) for task #{iOtherTask.Name}. Schedule is now [#{iOtherAssignmentInfo.MinStartDate}..#{iOtherAssignmentInfo.MinEndDate}(#{iOtherAssignmentInfo.MinEndDateHours})]. Now shift successors."
              end
              # 1.3.4.1.
              ioConsequences.ShiftedTasks[iOtherTask] = PathsManager::ShiftedTaskConsequences_Type.new
              # 1.3.4.2.
              TaskAssignmentManager.notifyMinimalEndDateChanged(iOtherTask, lMinEndDateDelay, ioAssignmentInfo, [], iMinimalPathImportance, ioConsequences.ShiftedTasks[iOtherTask], iAssignmentStrategies)
              # Update propagation of consequences
              if (!ioConsequences.ShiftedTasks[iOtherTask].PossibleConsequence)
                ioConsequences.PossibleConsequence = false
              end
              if (ioConsequences.ShiftedTasks[iOtherTask].MaximalShiftedImportance > ioConsequences.MaximalShiftedImportance)
                ioConsequences.MaximalShiftedImportance = ioConsequences.ShiftedTasks[iOtherTask].MaximalShiftedImportance
                ioConsequences.DelayOfMaximalShiftedImportance = ioConsequences.ShiftedTasks[iOtherTask].DelayOfMaximalShiftedImportance
              end
              # 1.3.4.3.
              if (!ioConsequences.PossibleConsequence)
                # 1.3.4.3.1.
                return
              end
            end
            # 1.3.5.
            if (lStartDateToShift)
              # 1.3.5.1.
              ImportanceManager.updatePredecessorsImportances(iOtherTask, ioAssignmentInfo)
            end
          end
        end
      end
    end

    # Method invoked when the minimal end date of a task has changed
    #
    # Parameters:
    # * *iTask* (_Task_): The task that changed
    # * *iDelay* (_Integer_): The number of days the task's minimal end date has been delayed
    # * *ioAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The current availability of resources to modify
    # * *iTasksListToIgnore* (<em>list<Task></em>): The tasks list we have to ignore due to a recursive call
    # * *iMinimalPathImportance* (_Integer_): The current path's minimal importance, used to update the non optimal delays of the assignment info
    # * *ioConsequences* (<em>ShiftedTaskConsequences_Type</em>): The consequences to fill.
    # * *iAssignmentStrategies* (<em>list<AssignmentStrategy></em>): The list of assignment strategies to consider
    def self.notifyMinimalEndDateChanged(iTask, iDelay, ioAssignmentInfo, iTasksListToIgnore, iMinimalPathImportance, ioConsequences, iAssignmentStrategies)
      # 1.
      if (ioAssignmentInfo[iTask].AvailableHours < iTask.Sizing)
        if ($Debug)
          puts "Task #{iTask.Name} has not enough resources (#{iTask.Sizing} hours needed, and only #{ioAssignmentInfo[iTask].AvailableHours} available). Therefore it can not be shifted to [#{ioAssignmentInfo[iTask].MinStartDate}..#{ioAssignmentInfo[iTask].MinEndDate}(#{ioAssignmentInfo[iTask].MinEndDateHours})]."
        end
        # 1.1.
        ioConsequences.addImpossibleSubShiftedTask(iTask)
      # 2.
      else
        # 2.1.
        lOldImportance = ioAssignmentInfo[iTask].Importance
        # 2.2.
        if (ioAssignmentInfo[iTask].AvailableHours == iTask.Sizing)
          if ($Debug)
            puts "Task #{iTask.Name} can be shifted to [#{ioAssignmentInfo[iTask].MinStartDate}..#{ioAssignmentInfo[iTask].MinEndDate}(#{ioAssignmentInfo[iTask].MinEndDateHours})], but has now no freedom anymore. Assign it for real."
          end
          # 2.2.1.
          SolutionManager.assignCompleteTask(iTask, iTasksListToIgnore, iMinimalPathImportance, ioAssignmentInfo, ioConsequences, iAssignmentStrategies)
        # 2.3.
        else
          if ($Debug)
            puts "Successor #{iTask.Name} can be shifted correctly to [#{ioAssignmentInfo[iTask].MinStartDate}..#{ioAssignmentInfo[iTask].MinEndDate}(#{ioAssignmentInfo[iTask].MinEndDateHours})]. Now try to shift its successors also, after the new minimal end date #{ioAssignmentInfo[iTask].MinEndDate} that has bee shifted of #{iDelay} days."
          end
          # 2.3.1.
          lImpossibleTask, lMaxPriorityShiftedForShift = TaskAssignmentManager.shiftChildrenTasks(iTask, ioAssignmentInfo[iTask].MinEndDate + 1, iTasksListToIgnore + [iTask], iMinimalPathImportance, ioAssignmentInfo, ioConsequences, iAssignmentStrategies)
          # 2.3.2.
          ImportanceManager.updateImportance(iTask, ioAssignmentInfo)
        end
        # 2.4.
        lMaximalShiftedImportance = lOldImportance
        lDelayOfMaximalShiftedImportance = iDelay + ioAssignmentInfo[iTask].NonOptimalAccumulatedDelay
        lPossibleConsequence = true
        ioConsequences.ShiftedTasks.each do |iSubShiftedTask, iSubShiftedTaskConsequences|
          if (iSubShiftedTaskConsequences.MaximalShiftedImportance > lMaximalShiftedImportance)
            lMaximalShiftedImportance = iSubShiftedTaskConsequences.MaximalShiftedImportance
            lDelayOfMaximalShiftedImportance = iSubShiftedTaskConsequences.DelayOfMaximalShiftedImportance
          elsif ((iSubShiftedTaskConsequences.MaximalShiftedImportance == lMaximalShiftedImportance) and
                 (iSubShiftedTaskConsequences.DelayOfMaximalShiftedImportance > lDelayOfMaximalShiftedImportance))
            lDelayOfMaximalShiftedImportance = iSubShiftedTaskConsequences.DelayOfMaximalShiftedImportance
          end
          if (!iSubShiftedTaskConsequences.PossibleConsequence)
            lPossibleConsequence = false
          end
        end
        ioConsequences.MaximalShiftedImportance = lMaximalShiftedImportance
        ioConsequences.DelayOfMaximalShiftedImportance = lDelayOfMaximalShiftedImportance
        ioConsequences.PossibleConsequence = lPossibleConsequence
        # 2.5.
        if (ioConsequences.MaximalShiftedImportance > iMinimalPathImportance)
          # 2.5.1.
          ioAssignmentInfo[iTask].NonOptimalAccumulatedDelay += iDelay
        end
        if ($Debug)
          puts "After shifting all successors recursively, #{iTask.Name} has importance #{ioAssignmentInfo[iTask].Importance}. The shifted priority of the operation is #{ioConsequences.MaximalShiftedImportance}."
        end
      end
    end
    
  end

end
