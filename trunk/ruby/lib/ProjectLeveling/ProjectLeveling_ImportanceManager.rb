
module ProjectLeveling

  # Importance manager
  class ImportanceManager

    # Populate importances recursively
    #
    # Parameters:
    # * *iTask* (_Task_): The task for which we populate the importance.
    # * *ioAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The assignment context that contains the maps to be updated
    def self.populateImportances(iTask, ioAssignmentInfo)
      # 1.
      if (ioAssignmentInfo[iTask].Importance == nil)
        # 1.1.
        iTask.Successors.each do |iChildTask|
          # 1.1.1.
          ImportanceManager.populateImportances(iChildTask, ioAssignmentInfo)
        end
        # 1.2.
        ImportanceManager.updateImportance(iTask, ioAssignmentInfo)
      end
    end
    
    # Insert the task in a sorted list
    #
    # Parameters:
    # * *ioTasksList* (<em>list<AssignedTaskID_Type></em>): The tasks list to insert into
    # * *iTask* (_Task_): The task to insert
    # * *iAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The current assignment info
    def self.insertInSortedTaskList(ioTasksList, iTask, iAssignmentInfo)
      # Get its importance and insert it in a sorted way
      lImportance = iAssignmentInfo[iTask].Importance
      lIdxTask = 0
      ioTasksList.each do |iAlreadySortedTask|
        if (iAssignmentInfo[iAlreadySortedTask.Task].Importance < lImportance)
          # We have to insert iTask just before iAlreadySortedTask
          ioTasksList.insert(lIdxTask, SolutionManager::AssignedTaskID_Type.new(iTask, 0))
          break
        end
        lIdxTask += 1
      end
      # If it is not yet inserted, do it at the end
      if (ioTasksList.size == lIdxTask)
        ioTasksList << SolutionManager::AssignedTaskID_Type.new(iTask, 0)
      end
    end

    # Get sorted tasks list
    #
    # Parameters:
    # * *iTasksList* (<em>list<Task></em>): The tasks list to sort
    # * *iAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The current assignment info
    # Return:
    # * <em>list<AssignedTaskID_Type></em>: The tasks list sorted
    def self.getSortedTasks(iTasksList, iAssignmentInfo)
      # 1.
      rSortedTasksList = []
      
      # Initialize lVisibleSortedTasksList with tasks having no predecessor.
      lVisibleSortedTasksList = []
      iTasksList.each do |iTask|
        if (iAssignmentInfo[iTask].FinalAssignment == nil)
          # Check that all predecessors are validated
          lAllPredecessorsValidated = true
          iTask.Predecessors.each do |iPredecessorTask|
            if (iAssignmentInfo[iPredecessorTask].FinalAssignment == nil)
              lAllPredecessorsValidated = false
              break
            end
          end
          if (lAllPredecessorsValidated)
            ImportanceManager.insertInSortedTaskList(lVisibleSortedTasksList, iTask, iAssignmentInfo)
          end
        end
      end
      # 2.
      while (!lVisibleSortedTasksList.empty?) do
        lAssignedTask = lVisibleSortedTasksList[0]
        lVisibleSortedTasksList = lVisibleSortedTasksList[1..-1]
        # 2.1.
        rSortedTasksList << lAssignedTask
        # 2.2.
        lAssignedTask.Task.Successors.each do |iChildTask|
          # 2.2.1.
          if (iAssignmentInfo[iChildTask].FinalAssignment == nil)
            lNotYetVisible = false
            iChildTask.Predecessors.each do |iPredecessor|
              # Check if iPredecessor is part of rSortedTasksList or is validated
              if (iAssignmentInfo[iPredecessor].FinalAssignment == nil)
                lPresent = false
                rSortedTasksList.each do |iAssignedTask|
                  if (iAssignedTask.Task == iPredecessor)
                    lPresent = true
                    break
                  end
                end
                if (!lPresent)
                  lNotYetVisible = true
                  break
                end
              end
            end
            if (!lNotYetVisible)
              # 2.2.1.1.
              ImportanceManager.insertInSortedTaskList(lVisibleSortedTasksList, iChildTask, iAssignmentInfo)
            end
          end
        end
      end
      
      # 3.
      return rSortedTasksList
    end

    # Update recursively the importance of predecessors
    #
    # Parameters:
    # * *iTask* (_Task_): The task for which we update the predecessors' importances.
    # * *ioAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The current assignment context.
    def self.updatePredecessorsImportances(iTask, ioAssignmentInfo)
      # 1.
      iTask.Predecessors.each do |iParentTask|
        if (ioAssignmentInfo[iParentTask].FinalAssignment == nil)
          # 1.1.
          lChanged = ImportanceManager.updateImportance(iParentTask, ioAssignmentInfo)
          # 1.2.
          if (lChanged)
            # 1.2.1.
            ImportanceManager.updatePredecessorsImportances(iParentTask, ioAssignmentInfo)
          end
        end
      end
    end

    # Update the importance of a single task (not recursive)
    #
    # Parameters:
    # * *iTask* (_Task_): The task we want to compute the importance of
    # * *ioAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The current availability of resources to modify
    # Return:
    # * _Boolean_: Has the importance been effectively changed ?
    def self.updateImportance(iTask, ioAssignmentInfo)
      # 1.
      lNewImportance = iTask.Priority
      lTaskMinEndDate = ioAssignmentInfo[iTask].MinEndDate
      # 2.
      iTask.Successors.each do |iChildTask|
        # 2.1.
        if ((ioAssignmentInfo[iChildTask].MinStartDate - lTaskMinEndDate <= 1) and
            (ioAssignmentInfo[iChildTask].Importance > lNewImportance))
          # 2.1.1.
          lNewImportance = ioAssignmentInfo[iChildTask].Importance
        end
      end
      # 3.
      if (lNewImportance != ioAssignmentInfo[iTask].Importance)
        # 3.1.
        ioAssignmentInfo[iTask].Importance = lNewImportance
        # 3.2.
        # TODO
        # 3.3.
        return true
      # 4.
      else
        # 4.1.
        return false
      end
    end

  end
  
end
