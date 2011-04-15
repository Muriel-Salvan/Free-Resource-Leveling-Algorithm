#--
# Copyright (c) 2007 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module ProjectLeveling

  # Paths manager
  class PathsManager
  
    # Class containing consequences of a task whose minimal end date has changed
    class ShiftedTaskConsequences_Type
    
      include Comparable
      
      #   Boolean
      attr_accessor :PossibleConsequence
      
      #   Integer
      attr_accessor :MaximalShiftedImportance
      
      #   Integer
      attr_accessor :DelayOfMaximalShiftedImportance
      
      #   map< Task, ShiftedTaskConsequences_Type >
      attr_accessor :ShiftedTasks
      
      # Constructor
      def initialize
        @PossibleConsequence = true
        @MaximalShiftedImportance = 0
        @DelayOfMaximalShiftedImportance = 0
        @ShiftedTasks = {}
      end
      
      # Method adding a new sub shifted task consequences.
      # This consequence is impossible.
      #
      # Parameters:
      # * *iSubShiftedTask* (_Task_): The task being shifted
      def addImpossibleSubShiftedTask(iSubShiftedTask)
        @ShiftedTasks[iSubShiftedTask] = ShiftedTaskConsequences_Type.new
        @ShiftedTasks[iSubShiftedTask].PossibleConsequence = false
      end

      # Method adding a new shifted task consequences. It will update PossibleConsequence, MaximalShiftedImportance and DelayOfMaximalShiftedImportance accordingly
      #
      # Parameters:
      # * *iShiftedTask* (_Task_): The task being shifted
      # * *iShiftedTaskConsequences* (<em>ShiftedTaskConsequences_Type</em>): The shifted task consequences
      def addShiftedTask(iShiftedTask, iShiftedTaskConsequences)
        # If there is already an impossibility, don't update anything
        if (@PossibleConsequence)
          # Check if this first consequence is possible
          if (!iShiftedTaskConsequences.Possible)
            @PossibleConsequence = false
          else
            # Consequences are possible. Update the delay.
            if (@MaximalShiftedImportance < iShiftedTaskConsequences.MaximalShiftedImportance)
              @MaximalShiftedImportance = iShiftedTaskConsequences.MaximalShiftedImportance
              @DelayOfMaximalShiftedImportance = iShiftedTaskConsequences.DelayOfMaximalShiftedImportance
            end
          end
        end
        @ShiftedTasks[iShiftedTask] = iShiftedTaskConsequences
      end
    
      # Compares 2 shifted task consequences
      # Compares:
      # 1. MaximalShiftedImportance, then (in case of equality)
      # 2. DelayOfMaximalShiftedImportance, then (in case of equality)
      # 3. The maximum MaximalShiftedImportance of all sub-shifted tasks, then (in case of equality)
      # 4. The delay of the respectively found (at step 3.) maximal MaximalShiftedImportance, then (in case of equality)
      # 5. Recursively 3. with the respectively found (at step 3.) maximal MaximalShiftedImportance's task, then (in case of equality)
      # 6. The same as points 3., 4., 5., with the next biggest importance/delay shifted, and so on (recursively), then (in case of equality)
      # 7. Nothing, they are equal
      #
      # Parameters:
      # * *iShiftedTaskConsequences* (<em>ShiftedTaskConsequences_Type</em>): The other shifted task consequences
      # Result:
      # * _Integer_: 0, 1 or -1 as comparison
      def <=>(iOtherShiftedTaskConsequences)
        rResult = 1
        
        # Step 1.
        lDiffImportance = @MaximalShiftedImportance - iOtherShiftedTaskConsequences.MaximalShiftedImportance
        if (lDiffImportance < 0)
          rResult = -1
        elsif (lDiffImportance == 0)
          # Step 2.
          lDiffDelay = @DelayOfMaximalShiftedImportance - iOtherShiftedTaskConsequences.DelayOfMaximalShiftedImportance
          if (lDiffDelay < 0)
            rResult = -1
          elsif (lDiffDelay == 0)
            # Step 3.
            rResult = ShiftedTaskConsequences_Type.compareSubShiftedTasksConsequencesList([self], [iOtherShiftedTaskConsequences])
          end
        end
        
        return rResult
      end
      
      # Compares 2 different set of sub shifted task consequences
      #
      # Parameters:
      # * *iSelfShiftedTaskConsequencesList* (<em>list<ShiftedTaskConsequences_Type></em>): The first list
      # * *iOtherShiftedTaskConsequencesList* (<em>list<ShiftedTaskConsequences_Type></em>): The second list
      # Result:
      # * _Integer_: 0, 1 or -1 as comparison
      def self.compareSubShiftedTasksConsequencesList(iSelfShiftedTaskConsequencesList, iOtherShiftedTaskConsequencesList)
        rResult = nil

        # Get the list of sub-shifted tasks' importances and delays for each consequences
        # list< [ Importance, Delay, list< ShiftedTaskConsequences > ] >
        lSelfSubImportancesList = ShiftedTaskConsequences_Type.getSubImportancesDelaysList(iSelfShiftedTaskConsequencesList)
        lOtherSubImportancesList = ShiftedTaskConsequences_Type.getSubImportancesDelaysList(iOtherShiftedTaskConsequencesList)
        # Now we process each level of importance/delay
        lIdxImportance = 0
        while (rResult == nil)
          if (lOtherSubImportancesList.size == lIdxImportance)
            if (lSelfSubImportancesList.size == lIdxImportance)
              rResult = 0
            else
              rResult = 1
            end
          elsif (lSelfSubImportancesList.size == lIdxImportance)
            rResult = -1
          else
            lSelfImportance, lSelfDelay, lSelfConsequencesList = lSelfSubImportancesList[lIdxImportance]
            lOtherImportance, lOtherDelay, lOtherConsequencesList = lOtherSubImportancesList[lIdxImportance]
            lDiffImportance = lSelfImportance - lOtherImportance
            # Compare importances
            if (lDiffImportance < 0)
              rResult = -1
            elsif (lDiffImportance > 0)
              rResult = 1
            else
              # Compare delays
              lDiffDelay = lSelfDelay - lOtherDelay
              if (lDiffDelay < 0)
                rResult = -1
              elsif (lDiffDelay > 0)
                rResult = 1
              else
                # Compare lists
                lDiffNbrTasks = lSelfConsequencesList.size - lOtherConsequencesList.size
                if (lDiffNbrTasks < 0)
                  rResult = -1
                elsif (lDiffNbrTasks > 0)
                  rResult = 1
                else
                  # Here, we have the same level of importance and delays, and the same number of tasks shifted for this importance/delay.
                  # So we recursively consider the sub-sub-shifted tasks
                  rResult = ShiftedTaskConsequences_Type.compareSubShiftedTasksConsequencesList(lSelfConsequencesList, lOtherConsequencesList)
                  if (rResult == 0)
                    # Try again with the next level of importance/delay
                    rResult = nil
                  end
                end
              end
            end
          end
          lIdxImportance += 1
        end
        # Forcefully here we have rResult != nil

        return rResult
      end
      
      # Get the complete list of sub-shifted task consequences from a list, sorted by decreasing importance and decreasing delay
      #
      # Parameters:
      # * *iTasksConsequencesList* (<em>list<ShiftedTaskConsequences_Type></em>): The list of shifted tasks consequences
      # Return:
      # * <em>list<[Integer,Integer,list<ShiftedTaskConsequences_Type>]></em>: The list
      def self.getSubImportancesDelaysList(iTasksConsequencesList)
        rResult = []
        
        iTasksConsequencesList.each do |iTaskConsequences|
          iTaskConsequences.ShiftedTasks.each do |iShiftedTask, iShiftedTaskConsequences|
            # Search for the line of rResult containing this importance/delay
            lIdxInsertPosition = 0
            rResult.each do |iIDInfo|
              iImportance, iDelay, iConsequencesList = iIDInfo
              if ((iImportance < iShiftedTaskConsequences.MaximalShiftedImportance) or
                  ((iImportance == iShiftedTaskConsequences.MaximalShiftedImportance) and
                   (iDelay < iShiftedTaskConsequences.DelayOfMaximalShiftedImportance)))
                # The line is not present in rResult.
                # Insert it at position lIdxInsertPosition
                break
              elsif ((iImportance == iShiftedTaskConsequences.MaximalShiftedImportance) and
                     (iDelay == iShiftedTaskConsequences.DelayOfMaximalShiftedImportance))
                # We found it
                # No need to insert, just add to this list of consequences
                lIdxInsertPosition = nil
                iConsequencesList << iShiftedTaskConsequences
                break
              end
              # The line lies further in the list
              lIdxInsertPosition += 1
            end
            if (lIdxInsertPosition != nil)
              # Insert it
              rResult.insert(lIdxInsertPosition, [iShiftedTaskConsequences.MaximalShiftedImportance, iShiftedTaskConsequences.DelayOfMaximalShiftedImportance, [iShiftedTaskConsequences] ])
            end
          end
        end
        
        return rResult
      end

    end
    
    # Class that gives info on a shifted task (used as a cache for findPossibleBetterPathforTask)
    class ShiftedTaskInfo_Type
    
      include Comparable
      
      #   Task
      attr_accessor :ShiftedTask
    
      #   Task
      attr_accessor :ShiftingTask
    
      #   ShiftedTaskConsequences_Type
      attr_accessor :ShiftedConsequences
    
      #   Integer
      attr_accessor :RemainingTasksToAssign
      
      # Constructor
      def initialize(iShiftedTask, iShiftingTask, iShiftedConsequences, iRemainingTasksToAssign)
        @ShiftedTask = iShiftedTask
        @ShiftingTask = iShiftingTask
        @ShiftedConsequences = iShiftedConsequences
        @RemainingTasksToAssign = iRemainingTasksToAssign
      end
      
      # Compares 2 shifted task info
      #
      # Parameters:
      # * *iShiftedTaskInfo* (<em>ShiftedTaskInfo_Type</em>): The other shifted task info
      # Result:
      # * _Integer_: 0, 1 or -1 as comparison
      def <=>(iShiftedTaskInfo)
        # Compare first consequences
        lOtherConsequencesBigger = (@ShiftedConsequences <=> iShiftedTaskInfo.ShiftedConsequences)
        if ((lOtherConsequencesBigger < 0) or
            ((lOtherConsequencesBigger == 0) and
             ((@RemainingTasksToAssign < iShiftedTaskInfo.RemainingTasksToAssign) or
              ((@RemainingTasksToAssign == iShiftedTaskInfo.RemainingTasksToAssign) and
               ((@ShiftedTask.Name < iShiftedTaskInfo.ShiftedTask.Name) or
                ((@ShiftedTask.Name == iShiftedTaskInfo.ShiftedTask.Name) and
                 (@ShiftingTask.Name < iShiftedTaskInfo.ShiftingTask.Name)))))))
          return -1
        elsif ((lOtherConsequencesBigger > 0) or
               (@RemainingTasksToAssign > iShiftedTaskInfo.RemainingTasksToAssign) or
               (@ShiftedTask.Name > iShiftedTaskInfo.ShiftedTask.Name) or
               (@ShiftingTask.Name > iShiftedTaskInfo.ShiftingTask.Name))
          return 1
        else
          return 0
        end
      end
      
    end
    
    # Class that stores information about a node of the already tried paths tree.
    class PathNode_Type
    
      #   ShiftedTaskConsequences_Type
      attr_accessor :Consequences
      
      #   AssignmentInfo_Type
      attr_accessor :AssignmentInfo
      
      #   Integer
      attr_accessor :PathMinimalImportance
      
      #   map< Task, TaskAssignmentPossibilities_Type >
      attr_accessor :TaskPaths
      
      # Constructor
      #
      # Parameters:
      # * *iConsequences* (<em>ShiftedTaskConsequences_Type</em>): The consequences of this assignment
      # * *iPathMinimalImportance* (_Integer_): The path minimal importance
      # * *iTaskPaths* (<em>map<Task,TaskAssignmentPossibilities_Type></em>): The new task paths
      def initialize(iConsequences, iPathMinimalImportance, iTaskPaths)
        @Consequences = iConsequences
        @AssignmentInfo = nil
        @PathMinimalImportance = iPathMinimalImportance
        @TaskPaths = iTaskPaths
      end
    
    end
    
    # Class representing the different path possibilities among a node of the already
    # tried paths' tree. This class gives for a given task the different
    # possibilities tried, 1 per iteration (way of assigning the task to its resources).
    class TaskAssignmentPossibilities_Type
      
      #   Integer
      attr_accessor :InitialTaskImportance
      
      #   Boolean
      attr_accessor :SolutionFound
      
      #   list< AssignedTaskID_Type >
      attr_accessor :RemainingTasks
      
      #   list< ShiftedTaskInfo_Type >
      attr_accessor :ShiftedTasksList
      
      #   list< list< AssignedTaskID_Type > >
      attr_accessor :AlreadyTriedSearches
      
      #   map< Integer, PathNode_Type >
      attr_accessor :Iterations
      
      # Constructor
      #
      # Parameters:
      # * *iInitialTaskImportance* (_Integer_): The importance of the task
      def initialize(iInitialTaskImportance)
        @InitialTaskImportance = iInitialTaskImportance
        @SolutionFound = false
        @RemainingTasks = nil
        @ShiftedTasksList = nil
        @AlreadyTriedSearches = []
        @Iterations = {}
      end
      
    end
    
    if ($Debug)
    
      # Display an already tried path
      #
      # Parameters:
      # * *iTree* (<em>PathNode_Type</em>): The tree
      # * *iPrefix* (_String_): The prefix used in display. This is used for indentation purposes. [optional = '']
      # * *iNodeToMark* (<em>map<Task,IterationPossibilites_Type></em>): The node that we want to locate. [optional = nil]
      def self.displayTree(iTree, iPrefix = '', iNodeToMark = nil)
        lStrNodePosition = ''
        if ((iNodeToMark != nil) and
            (iNodeToMark.object_id == iTree.object_id))
          lStrNodePosition = " - !!! NODE POSITION !!!"
        end
        lStrConsequences = ''
        if (iTree.Consequences == nil)
          lStrConsequences = ' - Optimal path'
        end
        lStrAssignmentInfo = ''
        if (iTree.AssignmentInfo != nil)
          lStrAssignmentInfo = ' - Assignment info saved'
        end
        puts "#{iPrefix}+-PathMinimalImportance=#{iTree.PathMinimalImportance}#{lStrAssignmentInfo}#{lStrConsequences}#{lStrNodePosition}"
        if (iTree.Consequences != nil)
          puts "#{iPrefix}+-Consequences:"
          self.displayShiftedTaskConsequences(nil, iTree.Consequences, "#{iPrefix}| ")
        end
        # Display by tasks' name ascending
        puts "#{iPrefix}+-Possible tasks:"
        lTaskNamesIndex = {}
        iTree.TaskPaths.keys.each do |iTask|
          lTaskNamesIndex[iTask.Name] = iTask
        end
        lIdxTask = 0
        lTaskNamesIndex.keys.sort.each do |iTaskName|
          lStrFollowNextTask = '| '
          if (lIdxTask == iTree.TaskPaths.size - 1)
            lStrFollowNextTask = '  '
          end
          iTask = lTaskNamesIndex[iTaskName]
          iIterationPossibilities = iTree.TaskPaths[iTask]
          if (iIterationPossibilities != nil)
            # Display all iteration possibilities
            lStrRemainingTasks = ''
            if (iIterationPossibilities.RemainingTasks != nil)
              lStrRemainingTasks = " RemainingTasks=#{SolutionManager.formatAssignedTasksList(iIterationPossibilities.RemainingTasks)}"
            end
            puts "#{iPrefix}  +-#{iTask.Name}: InitialTaskImportance=#{iIterationPossibilities.InitialTaskImportance} SolutionFound=#{iIterationPossibilities.SolutionFound}#{lStrRemainingTasks}"
            lIdxIteration = 0
            iIterationPossibilities.Iterations.each do |iIterationNbr, iPathInfo|
              lStrFollowNextIteration = '| '
              if (lIdxIteration == iIterationPossibilities.Iterations.size - 1)
                lStrFollowNextIteration = '  '
              end
              puts "#{iPrefix}  #{lStrFollowNextTask}+-[#{iTask.Name}, #{iIterationNbr}]"
              displayTree(iPathInfo, "#{iPrefix}  #{lStrFollowNextTask}#{lStrFollowNextIteration}", iNodeToMark)
              lIdxIteration += 1
            end
          else
            puts "#{iPrefix}  +-(#{iTask.Name})"
          end
          lIdxTask += 1
        end
      end
      
      # Display a path of AssignedTaskID
      #
      # Parameters:
      # * *iPath* (<em>list<AssignedTaskID_Type></em>): The path
      # * *iStrPrefix* (_String_): The display prefix. [optional = '']
      def self.displayPath(iPath, iStrPrefix = '')
        puts "#{iStrPrefix}#{SolutionManager.formatAssignedTasksList(iPath)}"
      end
      
      # Display task assignment consequences
      #
      # Parameters:
      # * *iTask* (_Task_): The task for which we display the consequences
      # * *iShiftedTaskConsequences* (<em>ShiftedTaskConsequences_Type</em>): The task assignment consequences
      # * *iStrPrefix* (_String_): The prefix to display
      def self.displayShiftedTaskConsequences(iTask, iShiftedTaskConsequences, iStrPrefix)
        lStrPossibleConsequence = 'Possible'
        if (!iShiftedTaskConsequences.PossibleConsequence)
          lStrPossibleConsequence = 'NOT Possible'
        end
        lStrTaskName = ''
        if (iTask != nil)
          lStrTaskName = "#{iTask.Name} "
        end
        puts "#{iStrPrefix}+-#{lStrTaskName}MaximalShiftedImportance=#{iShiftedTaskConsequences.MaximalShiftedImportance} (#{iShiftedTaskConsequences.DelayOfMaximalShiftedImportance} days) #{lStrPossibleConsequence} & #{iShiftedTaskConsequences.ShiftedTasks.size} shifted tasks"
        lIdxShiftedTask = 0
        iShiftedTaskConsequences.ShiftedTasks.each do |iShiftedTask, iSubShiftedTaskConsequences|
          lStrFollowNextShiftedTask = '| '
          if (lIdxShiftedTask == iShiftedTaskConsequences.ShiftedTasks.size - 1)
            lStrFollowNextShiftedTask = '  '
          end
          self.displayShiftedTaskConsequences(iShiftedTask, iSubShiftedTaskConsequences, "#{iStrPrefix}#{lStrFollowNextShiftedTask}")
          lIdxShiftedTask += 1
        end
      end
      
      # Display a shifted tasks list
      #
      # Parameters:
      # * *iShiftedTasksList* (<em>list<ShiftedTaskInfo_Type></em>): The list to display
      def self.displayShiftedTasksList(iShiftedTasksList)
        iShiftedTasksList.each do |iShiftedTaskInfo|
          puts "+-#{iShiftedTaskInfo.ShiftedTask.Name} (#{iShiftedTaskInfo.MaximalShiftedImportance} on #{iShiftedTaskInfo.DelayOfMaximalShiftedImportance} days) shifted by #{iShiftedTaskInfo.ShiftingTask.Name} (#{iShiftedTaskInfo.RemainingTasksToAssign} remaining tasks to assign)"
        end
      end
      
    end
    
    # Find a better path among the already tried paths
    #
    # Parameters:
    # * *iTask* (_Task_): The task that leads to a non-optimized path.
    # * *iCurrentPathNode* (<em>PathNode_Type</em>: The current node in the tree of already tried paths
    # * *iCurrentTasksList* (<em>list<AssignedTaskID_Type></em>): The list of tasks currently ordered.
    # Return:
    # * <em>list<AssignedTaskID_Type></em>: The new sort of tasks (or nil, if impossible to find)
    def self.findPossibleBetterPathForTask(iTask, iCurrentPathNode, iCurrentTasksList)
      # 1.
      lPresent = false
      iCurrentPathNode.TaskPaths[iTask].AlreadyTriedSearches.each do |iAlreadyTriedSearch|
        lPresent = false
        if (iAlreadyTriedSearch.size == iCurrentTasksList.size)
          lPresent = true
          iAlreadyTriedSearch.size.times do |iIdx|
            if (iAlreadyTriedSearch[iIdx].Task != iCurrentTasksList[iIdx].Task)
              lPresent = false
              break
            end
          end
        end
        if (lPresent)
          break
        end
      end
      if (lPresent)
        # 1.1.
        return nil
      # 2.
      else
        # 2.1.
        lShiftedTasksToSolve = []
        iCurrentPathNode.TaskPaths[iTask].ShiftedTasksList.each do |iShiftedTaskInfo|
          iShiftedTask = iShiftedTaskInfo.ShiftedTask
          iShiftingTask = iShiftedTaskInfo.ShiftingTask
          # If iShiftedTask is placed after iShiftingTask in iCurrentTasksList, add iShiftedTaskInfo in lShiftedTasksToSolve
          lShiftingTaskEncountered = false
          iCurrentTasksList.each do |iAssignedTaskID|
            if (iAssignedTaskID.Task == iShiftingTask)
              lShiftingTaskEncountered = true
            elsif (iAssignedTaskID.Task == iShiftedTask)
              if (lShiftingTaskEncountered)
                # It's ok, add it
                lShiftedTasksToSolve << iShiftedTaskInfo
              end
              # Else, iShiftedTask is placed before iShiftingTask, don't add it
              break
            end
          end
        end
        if ($Debug)
          puts "[#{iTask.Name}] - #{lShiftedTasksToSolve.size} tasks could be moved before previous ones to get a better path:"
          lIdx = 0
          lShiftedTasksToSolve.each do |iShiftedTaskToSolveInfo|
            iShiftedTask = iShiftedTaskToSolveInfo.ShiftedTask
            iShiftingTask = iShiftedTaskToSolveInfo.ShiftingTask
            iShiftedConsequences = iShiftedTaskToSolveInfo.ShiftedConsequences
            puts "[#{iTask.Name}] - #{lIdx} - #{iShiftedTask.Name} (I=#{iShiftedConsequences.MaximalShiftedImportance}, D=#{iShiftedConsequences.DelayOfMaximalShiftedImportance}), shifted by #{iShiftingTask.Name}."
            lIdx += 1
          end
        end
        # 2.2.
        iCurrentPathNode.TaskPaths[iTask].AlreadyTriedSearches << iCurrentTasksList
        # 2.3.
        lShiftedTasksToSolve.each do |iShiftedTaskToSolveInfo|
          iShiftedTask = iShiftedTaskToSolveInfo.ShiftedTask
          # 2.3.1.
          if (iTask.SharingResourcesTasksID == iShiftedTask.SharingResourcesTasksID)
            if ($Debug)
              puts "[#{iTask.Name}] - Try shifting #{iTask.Name} after #{iShiftedTask.Name}."
            end
            # 2.3.1.1.
            lNewPossiblePath = iCurrentTasksList.clone
            lNewShiftedTasksToSolve = lShiftedTasksToSolve.clone
            # 2.3.1.2.
            PathsManager.computeNewPathMovingTask(iTask, iShiftedTask, lNewPossiblePath, lNewShiftedTasksToSolve)
            if ($Debug)
              puts "[#{iTask.Name}] - Resulting branch: [ #{SolutionManager.formatAssignedTasksList(lNewPossiblePath)} ]."
            end
            # 2.3.1.3.
            rUnknownBranch = PathsManager.validateUnknownPath(iCurrentPathNode, lNewPossiblePath, lNewShiftedTasksToSolve)
            # 2.3.1.4.
            if (rUnknownBranch != nil)
              if ($Debug)
                puts "[#{iTask.Name}] - This branch was unknown: [ #{SolutionManager.formatAssignedTasksList(rUnknownBranch)} ]."
              end
              # 2.3.1.4.1.
              return rUnknownBranch
            # 2.3.1.5.
            else
              if ($Debug)
                puts "[#{iTask.Name}] - This branch was known. Now we try also moving other tasks to solve shifted ones and come to an unknown path."
              end
              # 2.3.1.5.1.
              rNewBranch = findUnknownPathReorderingShiftedTasks(iCurrentPathNode, lNewPossiblePath, lNewShiftedTasksToSolve)
              # 2.3.1.5.2.
              if (rNewBranch != nil)
                # 2.3.1.5.2.1.
                return rNewBranch
              end
            end
          end
        end
        # 2.4. TODO
        if (iCurrentPathNode == $AlreadyTriedPaths)
          if ($Debug)
            puts "[#{iTask.Name}] - All paths concerning the partitions of every shifted task that would need to be moved before previous ones have been tried. Now try to find a possible better path that forces a known non-optimal path."
          end
          # 2.4.1.
          rNewTasksList = PathsManager.findPossibleBetterPathAlreadyKnown(iCurrentPathNode, iCurrentTasksList)
          # 2.4.2.
          if (rNewTasksList != nil)
            # 2.4.2.1.
            return rNewTasksList
          end
        end
        # 2.5.
        return nil
      end
    end

    # Method that gets the list of shifted tasks, along with information about their shift (the task that has shifted it, and the importance and delay of the shift).
    #
    # Parameters:
    # * *iTask* (_Task_): The task for which we want to gather the shifted tasks list.
    # * *iAlreadyTriedPaths* (<em>PathNode_Type</em>): The path node to parse.
    # * *iNbrTasksToAssign* (_Integer_): The number of remaining tasks in the sub trees.
    def self.computeShiftedTasksList(iTask, iAlreadyTriedPaths, iNbrTasksToAssign)
      # 1.
      if (iAlreadyTriedPaths.TaskPaths[iTask].ShiftedTasksList == nil)
        # 1.1.
        rShiftedTasksList = []
        # 1.2.
        iAlreadyTriedPaths.TaskPaths[iTask].Iterations.each do |iItrNumber, iTaskIteration|
          # 1.2.1.
          if (iTaskIteration.Consequences == nil)
            # 1.2.1.1.
            iTaskIteration.TaskPaths.each do |iNextTask, iNextTaskAssignmentPossibilities|
              if (iNextTaskAssignmentPossibilities != nil)
                # 1.2.1.1.1.
                PathsManager.computeShiftedTasksList(iNextTask, iTaskIteration, iNbrTasksToAssign - 1)
                # 1.2.1.1.2.
                # Merge iNextTaskAssignmentPossibilities.ShiftedTasksList into rShiftedTasksList (2 sorted lists)
                lIdx = 0
                iNextTaskAssignmentPossibilities.ShiftedTasksList.each do |iNewShiftedTaskInfo|
                  if (iNewShiftedTaskInfo.ShiftedConsequences.MaximalShiftedImportance < iAlreadyTriedPaths.PathMinimalImportance)
                    # We know that we want to ignore this task and all its following ones.
                    break
                  end
                  while ((lIdx < rShiftedTasksList.size) and
                         (rShiftedTasksList[lIdx] < iNewShiftedTaskInfo))
                    lIdx += 1
                  end
                  # lIdx points to where we want to insert iNewShiftedTaskInfo if it is not already there
                  if ((lIdx == rShiftedTasksList.size) or
                      (rShiftedTasksList[lIdx] != iNewShiftedTaskInfo))
                    rShiftedTasksList.insert(lIdx, iNewShiftedTaskInfo)
                  end
                  # Make lIdx point to the next item. It is useless to start again at 0 because we know iNextTaskAssignmentPossibilities.ShiftedTasksList was sorted.
                  lIdx += 1
                end
              end
            end
          # 1.2.2.
          else
            # 1.2.2.1.
            iTaskIteration.Consequences.ShiftedTasks.each do |iShiftedTask, iShiftedTaskConsequences|
              # 1.2.2.1.1.
              if (!iShiftedTaskConsequences.PossibleConsequence)
                # 1.2.2.1.1.1.
                PathsManager.addShiftedTaskInfo(rShiftedTasksList,
                                                ShiftedTaskInfo_Type.new(iShiftedTask, iTask, iShiftedTaskConsequences, iNbrTasksToAssign))
              # 1.2.2.1.2.
              else
                # 1.2.2.1.2.1.
                if (iShiftedTaskConsequences.MaximalShiftedImportance >= iAlreadyTriedPaths.PathMinimalImportance)
                  # 1.2.2.1.2.1.1.
                  PathsManager.addShiftedTaskInfo(rShiftedTasksList,
                                                  ShiftedTaskInfo_Type.new(iShiftedTask, iTask, iShiftedTaskConsequences, iNbrTasksToAssign))
                end
              end
            end
          end
        end
        # 1.3.
        iAlreadyTriedPaths.TaskPaths[iTask].ShiftedTasksList = rShiftedTasksList
      end
    end
    
    # Insert a shifted task info in a sorted list
    #
    # Parameters:
    # * *ioShiftedTasksList* (<em>list<ShiftedTaskInfo_Type></em>): The list
    # * *iShiftedTaskInfo* (<em>ShiftedTaskInfo_Type</em>): The item to insert
    def self.addShiftedTaskInfo(ioShiftedTasksList, iShiftedTaskInfo)
      lIdx = 0
      ioShiftedTasksList.each do |iOtherShiftedTaskInfo|
        if (iShiftedTaskInfo < iOtherShiftedTaskInfo)
          lIdx += 1
        else
          break
        end
      end
      ioShiftedTasksList.insert(lIdx, iShiftedTaskInfo)
    end

    # Find an unknown path from a current node.
    #
    # Parameters:
    # * *iCurrentPathNode* (<em>PathNode_Type</em>): The current path node.
    # * *iCurrentTasksList* (<em>Branch_Type</em>): The current list of assigned tasks
    # * *iShiftedTasksToSolve* (<em>list< [ Task, Integer, Task ] ></em>): The ordered (by importance) tasks list that have to be moved before some others tasks.
    # Return:
    # * <em>Branch_Type</em>: The information of branch replacement that leads to a possible better path (or None if none found).
    def self.findUnknownPathReorderingShiftedTasks(iCurrentPathNode, iCurrentTasksList, iShiftedTasksToSolve)
      if ($Debug)
        lStrSTTSList = []
        iShiftedTasksToSolve.each do |iShiftedTaskToSolveInfo|
          iShiftedTask = iShiftedTaskToSolveInfo.ShiftedTask
          iShiftingTask = iShiftedTaskToSolveInfo.ShiftingTask
          iShiftedConsequences = iShiftedTaskToSolveInfo.ShiftedConsequences
          lStrSTTSList << "#{iShiftedTask.Name} (#{iShiftedConsequences.MaximalShiftedImportance}) shifted by #{iShiftingTask.Name} (#{iShiftedConsequences.DelayOfMaximalShiftedImportance} days)"
        end
        puts "----- try moving shifted tasks in the current tasks list: [ #{SolutionManager.formatAssignedTasksList(iCurrentTasksList)} ]. The shifted tasks to solve are: [ #{lStrSTTSList.join(', ')} ]."
      end
      # 1.
      lKnownPaths = []
      # 2.
      iShiftedTasksToSolve.each do |iShiftedTaskToSolveInfo|
        iShiftedTask = iShiftedTaskToSolveInfo.ShiftedTask
        iShiftingTask = iShiftedTaskToSolveInfo.ShiftingTask
        # 2.1.
        # First find index of iShiftingTask in iCurrentTasksList (it is forcefully present)
        lIdxCandidateTask = 0
        while (iCurrentTasksList[lIdxCandidateTask].Task != iShiftingTask)
          lIdxCandidateTask += 1
        end
        # lIdxCandidateTask points on iShiftingTask in iCurrentTasksList
        while (lIdxCandidateTask >= 0)
          iCandidateTask = iCurrentTasksList[lIdxCandidateTask].Task
          # 2.1.1.
          if (iCandidateTask.SharingResourcesTasksID == iShiftedTask.SharingResourcesTasksID)
            if ($Debug)
              puts "----- We can try to move #{iCandidateTask.Name} after #{iShiftedTask.Name}."
            end
            # 2.1.1.1.
            lNewPossiblePath = iCurrentTasksList.clone
            lNewShiftedTasksToSolve = iShiftedTasksToSolve.clone
            # 2.1.1.2.
            PathsManager.computeNewPathMovingTask(iCandidateTask, iShiftedTask, lNewPossiblePath, lNewShiftedTasksToSolve)
            if ($Debug)
              puts "----- Resulting branch: [ #{SolutionManager.formatAssignedTasksList(lNewPossiblePath)} ]."
            end
            # 2.1.1.3.
            rNewBranch = PathsManager.validateUnknownPath(iCurrentPathNode, lNewPossiblePath, lNewShiftedTasksToSolve)
            # 2.1.1.4.
            if (rNewBranch != nil)
              if ($Debug)
                puts "----- This branch was unknown: [ #{SolutionManager.formatAssignedTasksList(rUnknownBranch)} ]."
              end
              # 2.1.1.4.1.
              return rNewBranch
            # 2.1.1.5.
            else
              if ($Debug)
                puts "----- This branch was known. We remember it."
              end
              # 2.1.1.5.1.
              lKnownPaths << [ lNewPossiblePath, lNewShiftedTasksToSolve ]
            end
          end
          lIdxCandidateTask -= 1
        end
      end
      if ($Debug)
        puts "----- Moving just 1 task was not enough to get to an unknown branch. Try moving another task among the #{lKnownPaths.size} known paths we have just remembered."
      end
      # 3.
      lKnownPaths.each do |iKnownPathInfo|
        iNewKnownPath, iNewShiftedTasksToSolve = iKnownPathInfo
        # 3.1.
        rNewBranch = PathsManager.findUnknownPathReorderingShiftedTasks(iCurrentPathNode, iNewKnownPath, iNewShiftedTasksToSolve)
        # 3.2.
        if (rNewBranch != nil)
          if ($Debug)
            puts "----- We found the branch: [ #{SolutionManager.formatAssignedTasksList(rNewBranch)} ]."
          end
          # 3.2.1.
          return rNewBranch
        end
      end
      if ($Debug)
        puts "----- Failed to find a new branch."
      end
      # 4.
      return nil
    end
    
    # Method that moves a task after another one among an assigned tasks list.
    #
    # Parameters:
    # * *iTaskToMove* (_Task_): The task we want to move after another.
    # * *iTaskToPass* (_Task_): The task we want to get passed by iTaskToMove.
    # * *ioCurrentTasksList* (<em>Branch_Type</em>): The current assigned tasks list in which we want to perform the move.
    # * *ioShiftedTasksToSolve* (<em>list<ShiftedTaskInfo_Type></em>): The ordered (by importance) tasks list that have to be moved before some others tasks. It is given to be updated according to the move. If we don't need any update, just put None.
    def self.computeNewPathMovingTask(iTaskToMove, iTaskToPass, ioCurrentTasksList, ioShiftedTasksToSolve)
      # 1.
      # Find position of iTaskToMove in ioCurrentTasksList (it is forcefully present)
      lIdxTaskToMove = 0
      while (ioCurrentTasksList[lIdxTaskToMove].Task != iTaskToMove)
        lIdxTaskToMove += 1
      end
      lIdxParse = lIdxTaskToMove
      while ((lIdxParse == 0) or
             (ioCurrentTasksList[lIdxParse-1].Task != iTaskToPass))
        iPassingTask = ioCurrentTasksList[lIdxParse].Task
        # 1.1.
        if (iTaskToMove.Successors.include?(iPassingTask))
          # 1.1.1.
          PathsManager.computeNewPathMovingTask(iPassingTask, iTaskToPass, ioCurrentTasksList, ioShiftedTasksToSolve)
        end
        # 1.2.
        if (ioShiftedTasksToSolve != nil)
          # 1.2.1.
          if (iTaskToMove.SharingResourcesTasksID == iPassingTask.SharingResourcesTasksID)
            # 1.2.1.1.
            ioShiftedTasksToSolve.delete_if do |iShiftedTaskToSolveInfo|
              (iShiftedTaskToSolveInfo.ShiftedTask == iPassingTask)
            end
          end
        end
        lIdxParse += 1
      end
      # We arrived at the end: we delete occurences of the task to pass
      if (ioShiftedTasksToSolve != nil)
        # 1.2.1.1.
        ioShiftedTasksToSolve.delete_if do |iShiftedTaskToSolveInfo|
          (iShiftedTaskToSolveInfo.ShiftedTask == iTaskToPass)
        end
      end
      # 2.
      # lIdxParse points to then task just after iTaskToPass in ioCurrentTasksList
      # lIdxTaskToMove points to iTaskToMove in ioCurrentTasksList (lIdxTaskToMove < lIdxParse)
      ioCurrentTasksList.insert(lIdxParse, ioCurrentTasksList[lIdxTaskToMove])
      ioCurrentTasksList[lIdxParse].IterationNbr = 0
      ioCurrentTasksList.delete_at(lIdxTaskToMove)
    end
    
    # Method that validates a possible unknown path.
    #
    # Parameters:
    # * *iCurrentPathNode* (<em>PathNode_Type</em>): The current path node to start searching from.
    # * *iCurrentTasksList* (<em>Branch_Type</em>): The branch to test
    # * *iShiftedTasksToSolve* (<em>list< [ Task, Integer, Task ] ></em>): The ordered (by importance) tasks list that have to be moved before some others tasks.
    # Return:
    # * <em>Branch_Type</em>: The validated path (or None if the path was already tried).
    def self.validateUnknownPath(iCurrentPathNode, iCurrentTasksList, iShiftedTasksToSolve)
      # 1.
      lTask = iCurrentTasksList[0].Task
      if ($Debug)
        puts "------- Looking at task #{lTask.Name} in the path ..."
      end
      # 2.
      if (iCurrentPathNode.TaskPaths[lTask] == nil)
        if ($Debug)
          puts "------- The path is unknown. Now we just sort the rest according to the remaining shifted tasks to solve."
        end
        # 2.1.
        lSubTasksList = iCurrentTasksList[1..-1]
        # 2.2.
        lNewUnknownPart = PathsManager.reorderBranch(lSubTasksList, iShiftedTasksToSolve)
        # 2.3.
        return [ SolutionManager::AssignedTaskID_Type.new(lTask, 0) ] + lNewUnknownPart
      # 3.
      elsif (!iCurrentPathNode.TaskPaths[lTask].SolutionFound)
        if ($Debug)
          puts "------- The path is known and not optimal. Try finding a better path from it."
        end
        # 3.1.
      # 4.
      else
        if ($Debug)
          puts "------- The path is known and optimal to this task. Continue."
        end
        # 4.1.
        lPathCursor.TaskPaths[lTask].Iterations.each do |iIterationNbr, iNewPathNode|
          # 4.1.1.
          if (iNewPathNode.Consequences == nil)
            # 4.1.1.1.
            lSubTasksList = iCurrentTasksList[1..-1]
            # 4.1.1.2.
            lUnknownSubPath = PathsManager.validateUnknownPath(iNewPathNode, lSubTasksList, iShiftedTasksToSolve)
            # 4.1.1.3.
            if (lUnknownSubPath != nil)
              # 4.1.1.3.1.
              return [ SolutionManager::AssignedTaskID_Type.new(lTask, iIterationNbr) ] + lUnknownSubPath
            end
          end
        end
      end
      # 5.
      rNewBranch = PathsManager.findPossibleBetterPathForTask(lTask, iCurrentPathNode, iCurrentTasksList)
      # 6.
      return rNewBranch
    end
    
    # Method that takes a tasks' list (meant to be part of an unknown path), and changes its sort to make sure previously shifted tasks will have more chances to not get shifted again.
    #
    # Parameters:
    # * *iCurrentTasksList* (<em>Branch_Type</em>): The assigned tasks list to reorder.
    # * *iShiftedTasksToSolve* (<em>list< [ Task, Integer, Task ] ></em>): The ordered (by importance) tasks list that have to be moved before some others tasks.
    # Return:
    # * <em>Branch_Type</em>: The new assigned tasks list.
    def self.reorderBranch(iCurrentTasksList, iShiftedTasksToSolve)
      if ($Debug)
        lStrSTTSList = []
        iShiftedTasksToSolve.each do |iShiftedTaskToSolveInfo|
          iShiftedTask = iShiftedTaskToSolveInfo.ShiftedTask
          iShiftingTask = iShiftedTaskToSolveInfo.ShiftingTask
          iShiftedConsequences = iShiftedTaskToSolveInfo.ShiftedConsequences
          iNbrRemainingTasks = iShiftedTaskToSolveInfo.RemainingTasksToAssign
          lStrSTTSList << "#{iShiftedTask.Name} (#{iShiftedConsequences.MaximalShiftedImportance}) shifted by #{iShiftingTask.Name} (#{iShiftedConsequences.DelayOfMaximalShiftedImportance} days, #{iNbrRemainingTasks} remaining tasks to assign)"
        end
        puts "Blindly reorder [ #{SolutionManager.formatAssignedTasksList(iCurrentTasksList)} ], considering shifted tasks to solve: [ #{lStrSTTSList.join(', ')} ]."
      end
      # 1.
      rNewBranch = iCurrentTasksList.clone
      # 2.
      iShiftedTasksToSolve.each do |iShiftedTaskToSolveInfo|
        iShiftedTask = iShiftedTaskToSolveInfo.ShiftedTask
        iShiftingTask = iShiftedTaskToSolveInfo.ShiftingTask
        # 2.1.
        # Check that iShiftingTask is effectively placed before iShiftedTask (make sure both are part of iCurrentTasksList)
        lShiftingTaskFound = false
        lShiftedTaskFoundAfter = false
        iCurrentTasksList.each do |iAssignedTask|
          if (iAssignedTask.Task == iShiftedTask)
            if (lShiftingTaskFound)
              lShiftedTaskFoundAfter = true
            end
            break
          elsif (iAssignedTask.Task == iShiftingTask)
            lShiftingTaskFound = true
          end
        end
        if (lShiftedTaskFoundAfter)
          # 2.1.1.
          PathsManager.computeNewPathMovingTask(iShiftingTask, iShiftedTask, rNewBranch, nil)
        end
      end
      # 3.
      return rNewBranch
    end

    # Method that finds the best path among all the already tried ones.
    #
    # Parameters:
    # * *iAlreadyTriedPaths* (<em>PathNode_Type</em>): The already tried paths to consider.
    # * *iCurrentTasksList* (<em>Branch_Type</em>): The current tasks list (useful to decide between several possible better paths).
    # Return:
    # * <em>list<AssignedTaskID_Type></em>: The branch replacement leading to the possible better path.
    def self.findPossibleBetterPathAlreadyKnown(iAlreadyTriedPaths, iCurrentTasksList)
      if ($Debug)
        puts "Looking for already tried paths:"
        PathsManager.displayTree(iAlreadyTriedPaths)
      end
      # 1.
      lBranchesList, lConsequences = PathsManager.findSmallestShiftedConsequencesPaths(iAlreadyTriedPaths)
      if ($Debug)
        puts "#{lBranchesList.size} possible paths have been found minimizing consequences (Maximal shifted importance #{lConsequences.MaximalShiftedImportance}):"
        lIdx = 0
        lBranchesList.each do |iPathInfo|
          PathsManager.displayPath(iPathInfo[0], "- #{lIdx}: ")
          lIdx += 1
        end
      end
      # 2.
      rBranch = nil
      lPathNode = nil
      if (lBranchesList.size == 1)
        # 2.1.
        rBranch, lPathNode = lBranchesList[0]
      # 3.
      else
        # 3.1.
        rBranch, lPathNode = PathsManager.getBestPathAmongBestShiftedImportancePaths(iAlreadyTriedPaths, iCurrentTasksList, lBranchesList)
      end
      # 4.
      lPathNode.Consequences = nil
      # 5.
      return rBranch
    end
    
    # Return the best path among previously selected ones.
    #
    # Parameters:
    # * *iAlreadyTriedPaths* (<em>PathNode_Type</em>): The structure that contains the paths to check.
    # * *iCurrentTasksList* (<em>list<AssignedTaskID_Type></em>): The current ordered tasks list.
    # * *iBestPaths* (<em>list<[list<AssignedTaskID_Type>,PathNode_Type]></em>): The list of all possible best paths elected, with their corresponding path node that we want to force.
    # Return:
    # * <em>list<AssignedTaskID_Type></em>: The best path.
    # * <em>PathNode_Type</em>: Its corresponding path node to force.
    def self.getBestPathAmongBestShiftedImportancePaths(iAlreadyTriedPaths, iCurrentTasksList, iBestPaths)
      if ($Debug)
        puts "#{iBestPaths.size} paths have to be considered to get the best one, as they all shift the same minimal consequences:"
        lIdx = 0
        iBestPaths.each do |iPathInfo|
          PathsManager.displayPath(iPathInfo[0], "- #{lIdx}: ")
          lIdx += 1
        end
      end
      # 1.
      lSelectedPaths = [iBestPaths[0]]
      lImportancePath = []
      lCurrentPathNode = iAlreadyTriedPaths
      iBestPaths[0][0].each do |iAssignedTaskID|
        lTask = iAssignedTaskID.Task
        lIterationNbr = iAssignedTaskID.IterationNbr
        if (lCurrentPathNode.TaskPaths[lTask] != nil)
          lImportancePath << lCurrentPathNode.TaskPaths[lTask].InitialTaskImportance
        else
          break
        end
        # Test nil possibilities:
        # - lCurrentPathNode.TaskPaths[lTask] nil corresponds to a path where we never tried any iteration
        # - lCurrentPathNode.TaskPaths[lTask].Iterations[IterationNbr] nil corresponds to a path where we tried some of the iterations, but not all
        if ((lCurrentPathNode.TaskPaths[lTask] != nil) and
            (lCurrentPathNode.TaskPaths[lTask].Iterations[lIterationNbr] != nil))
          lCurrentPathNode = lCurrentPathNode.TaskPaths[lTask].Iterations[lIterationNbr]
        else
          break
        end
      end
      # 2.
      iBestPaths[1..-1].each do |iPathInfo|
        iPath, iNode = iPathInfo
        puts "---- Check #{SolutionManager.formatAssignedTasksList(iPath)}..."
        puts "---- Importances: #{lImportancePath.join(', ')}"
        # 2.1.
        lCurrentPathNode = iAlreadyTriedPaths
        lImportanceCursor = 0
        # 2.2.
        lGotoNextPath = false
        iPath.each do |iAssignedTaskID|
          lTask = iAssignedTaskID.Task
          lIterationNbr = iAssignedTaskID.IterationNbr
          puts "---- Checking assigned task (#{lTask.Name}, #{lIterationNbr})..."
          # 2.2.1.
          if (lImportancePath.size == lImportanceCursor)
            puts "---- This path is longer than the importances path. Take it along with others."
            # 2.2.1.1.
            lSelectedPaths << [ iPath, iNode ]
            # 2.2.1.2.
            lGotoNextPath = true
            break
          # 2.2.2.
          elsif (lCurrentPathNode.TaskPaths[lTask].InitialTaskImportance < lImportancePath[lImportanceCursor])
            puts "---- At task #{lTask.Name}, this path is less important (#{lCurrentPathNode.TaskPaths[lTask].InitialTaskImportance}) than then importances path (#{lImportancePath[lImportanceCursor]}). Forget it."
            # 2.2.2.1.
            lGotoNextPath = true
            break
          # 2.2.3.
          elsif (lCurrentPathNode.TaskPaths[lTask].InitialTaskImportance > lImportancePath[lImportanceCursor])
            puts "---- At task #{lTask.Name}, this path is more important (#{lCurrentPathNode.TaskPaths[lTask].InitialTaskImportance}) than then importances path (#{lImportancePath[lImportanceCursor]}). Take it, change the importances path, and forget previously taken paths longer than this one."
            # 2.2.3.1.
            lSelectedPaths.delete_if do |iSelectedPathInfo|
              iSelectedPathInfo[0].size > lImportanceCursor
            end
            # 2.2.3.2.
            lStartCursor = lImportanceCursor
            iPath[lStartCursor..-1].each do |iRemainingNewAssignedTask|
              lTask = iRemainingNewAssignedTask.Task
              lIterationNbr = iRemainingNewAssignedTask.IterationNbr
              if (lCurrentPathNode.TaskPaths[lTask] != nil)
                lImportancePath[lImportanceCursor] = lCurrentPathNode.TaskPaths[lTask].InitialTaskImportance
              else
                break
              end
              # Test both nil possibilities:
              # - lCurrentPathNode.TaskPaths[lTask] nil corresponds to a path where we never tried any iteration
              # - lCurrentPathNode.TaskPaths[lTask].Iterations[IterationNbr] nil corresponds to a path where we tried some of the iterations, but not all
              if ((lCurrentPathNode.TaskPaths[lTask] != nil) and
                  (lCurrentPathNode.TaskPaths[lTask].Iterations[lIterationNbr] != nil))
                lCurrentPathNode = lCurrentPathNode.TaskPaths[lTask].Iterations[lIterationNbr]
              else
                break
              end
              lImportanceCursor += 1
            end
            # 2.2.3.3.
            lSelectedPaths << [ iPath, iNode ]
            # 2.2.3.4.
            lGotoNextPath = true
            break
          # 2.2.4.
          else
            puts "---- At task #{lTask.Name}, this path is as important (#{lCurrentPathNode.TaskPaths[lTask].InitialTaskImportance}) as importances path. Continue looking up next task."
            # 2.2.4.1.
            lImportanceCursor += 1
            lCurrentPathNode = lCurrentPathNode.TaskPaths[lTask].Iterations[lIterationNbr]
          end
        end
        if (lGotoNextPath)
          next
        end
        # 2.3.
        lSelectedPaths << [ iPath, iNode ]
      end
      if ($Debug)
        puts "#{lSelectedPaths.size} paths assign the most important tasks first:"
        lIdx = 0
        lSelectedPaths.each do |iPathInfo|
          PathsManager.displayPath(iPathInfo[0], "- #{lIdx}: ")
          lIdx += 1
        end
      end
      # 3.
      if (lSelectedPaths.size == 1)
        # 3.1.
        return lSelectedPaths[0]
      # 4.
      else
        # 4.1.
        lTaskCursor = 0
        # 4.2.
        iCurrentTasksList.each do |iAssignedTask|
          lTask = iAssignedTask.Task
          # 4.2.1.
          lPathWithSameTaskExist = false
          lSelectedPaths.each do |iSelectedPathInfo|
            if (iSelectedPathInfo[0][lTaskCursor].Task == lTask)
              lPathWithSameTaskExist = true
              break
            end
          end
          if (lPathWithSameTaskExist)
            # 4.2.1.1.
            lSelectedPaths.delete_if do |iSelectedPathInfo|
              iSelectedPathInfo[0][lTaskCursor].Task != lTask
            end
          # 4.2.2.
          else
            # 4.2.2.1.
            lMinLength = nil
            lSelectedPaths.each do |iSelectedPathInfo|
              if ((lMinLength == nil) or
                  (iSelectedPathInfo[0].size < lMinLength))
                lMinLength = iSelectedPathInfo[0].size
              end
            end
            # 4.2.2.2.
            lSelectedPaths.delete_if do |iSelectedPathInfo|
              iSelectedPathInfo[0].size > lMinLength
            end
            # 4.2.2.3.
            break
          end
        end
        if ($Debug)
          puts "#{lSelectedPaths.size} paths are closest to the current path:"
          lIdx = 0
          lSelectedPaths.each do |iPathInfo|
            PathsManager.displayPath(iPathInfo[0], "- #{lIdx}: ")
            lIdx += 1
          end
        end
        # 4.3.
        return lSelectedPaths[0]
      end
    end
    
    # Find the list of paths that have the least shifted importance among what we already know.
    #
    # Parameters:
    # * *iCurrentPathNode* (<em>PathNode_Type</em>): The structure that contains the paths to check.
    # Return:
    # * <em>list<[list<AssignedTaskID_Type>,Branch_Type]></em>: The list of every path (the task and its assignment's iteration number) that minimizes the shifted importance, along with their corresponding PathNode_Type node in the paths' tree.
    # * <em>ShiftedTaskConsequences_Type</em>: The corresponding consequences
    def self.findSmallestShiftedConsequencesPaths(iCurrentPathNode)
      # 1.
      rBestPaths = []
      rBestConsequences = nil
      if ($Debug)
        puts 'Find smallest consequences.'
      end
      # 2.
      iCurrentPathNode.TaskPaths.each do |iTask, iIterationPossibilities|
        if (iIterationPossibilities != nil)
          iIterationPossibilities.Iterations.each do |iIterationNbr, iPathPossibilities|
            if ($Debug)
              puts "----- [ #{iTask.Name}, #{iIterationNbr} ] - Look into the sub tree..."
            end
            # 2.1.
            lBestSubPaths, lBestSubConsequences = PathsManager.findSmallestShiftedConsequencesPaths(iCurrentPathNode.TaskPaths[iTask].Iterations[iIterationNbr])
            if ($Debug)
              puts "----- [ #{iTask.Name}, #{iIterationNbr} ] - Retrieved #{lBestSubPaths.size} best paths from the sub tree."
            end
            # 2.2.
            if (lBestSubPaths.empty?)
              if ($Debug)
                puts "----- [ #{iTask.Name}, #{iIterationNbr} ] - Considering our own consequences."
              end
              # 2.2.1.
              lConsequences = iCurrentPathNode.TaskPaths[iTask].Iterations[iIterationNbr].Consequences
              lNewBranch = [ SolutionManager::AssignedTaskID_Type.new(iTask, iIterationNbr) ] + iCurrentPathNode.TaskPaths[iTask].RemainingTasks
              # 2.2.2.
              lDiffConsequences = -1
              if (rBestConsequences != nil)
                lDiffConsequences = (lConsequences <=> rBestConsequences)
              end
              if (lDiffConsequences < 0)
                if ($Debug)
                  puts "----- [ #{iTask.Name}, #{iIterationNbr} ] - Our own consequences are smaller than previously found. Replace previously found."
                end
                # 2.2.2.1.
                rBestPaths = [ [ lNewBranch, iCurrentPathNode.TaskPaths[iTask].Iterations[iIterationNbr] ] ]
                rBestConsequences = lConsequences
              # 2.2.3.
              elsif (lDiffConsequences == 0)
                if ($Debug)
                  puts "----- [ #{iTask.Name}, #{iIterationNbr} ] - Our own consequences are equal to the ones previously found. Add them to the list."
                end
                # 2.2.3.1.
                rBestPaths << [ lNewBranch, iCurrentPathNode.TaskPaths[iTask].Iterations[iIterationNbr] ]
              elsif ($Debug)
                puts "----- [ #{iTask.Name}, #{iIterationNbr} ] - Our own consequences are bigger than previously found. Forget them."
              end
            # 2.3.
            else
              # 2.3.1.
              lDiffConsequences = -1
              if (rBestConsequences != nil)
                lDiffConsequences = (lBestSubConsequences <=> rBestConsequences)
              end
              if (lDiffConsequences < 0)
                if ($Debug)
                  puts "----- [ #{iTask.Name}, #{iIterationNbr} ] - Returned consequences are smaller than previously found. Replace previously found."
                end
                # 2.3.1.1.
                lAddedList = [ SolutionManager::AssignedTaskID_Type.new(iTask, iIterationNbr) ]
                rBestPaths = []
                lBestSubPaths.each do |iPathInfo|
                  rBestPaths << [ lAddedList + iPathInfo[0], iPathInfo[1] ]
                end
                rBestConsequences = lBestSubConsequences
              # 2.3.2.
              elsif (lDiffConsequences == 0)
                if ($Debug)
                  puts "----- [ #{iTask.Name}, #{iIterationNbr} ] - Returned consequences are equal to the ones previously found. Add them to the list."
                end
                # 2.3.2.1.
                lAddedList = [ SolutionManager::AssignedTaskID_Type.new(iTask, iIterationNbr) ]
                lBestSubPaths.each do |iPathInfo|
                  rBestPaths << [ lAddedList + iPathInfo[0], iPathInfo[1] ]
                end
              elsif ($Debug)
                puts "----- [ #{iTask.Name}, #{iIterationNbr} ] - Returned consequences are bigger than previously found. Forget them."
              end
            end
          end
        end
      end
      # 3.
      return rBestPaths, rBestConsequences
    end

    # Add a path to the memory of already tried paths
    #
    # Parameters:
    # * *iCurrentPathNode* (<em>PathNode_Type</em>): The current path node to complete
    # * *iTask* (_Task_): The task to be added
    # * *iIterationNbr* (_Integer_): The iteration number to be added
    # * *iConsequences* (<em>ShiftedTaskConsequences_Type</em>): The consequences of this task's assignment
    # * *iInitialImportance* (_Integer_): The initial importance of the task before being assigned
    # * *iAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The current assignment info
    # Return:
    # * _Boolean_: Is the current branch an optimal path after adding the task ?
    def self.completeTriedPath(iCurrentPathNode, iTask, iIterationNbr, iConsequences, iInitialImportance, iAssignmentInfo)
      if ($Debug)
        puts "[#{iTask.Name}, #{iIterationNbr}] - Complete already tried paths. Initial task importance is #{iInitialImportance}. Current path has a minimal importance of #{iCurrentPathNode.PathMinimalImportance}. Here are the consequences:"
        self.displayShiftedTaskConsequences(iTask, iConsequences, '')
      end
      # 1.
      lNewTaskPaths = {}
      # 2.
      iCurrentPathNode.TaskPaths.keys.each do |iOldAccessibleTask|
        # 2.1.
        if (iOldAccessibleTask != iTask)
          # 2.1.1.
          lNewTaskPaths[iOldAccessibleTask] = nil
        end
      end
      # 3.
      iTask.Successors.each do |iSuccessorTask|
        # 3.1.
        lAllPredecessorsAssigned = true
        # 3.2.
        iSuccessorTask.Predecessors.each do |iPredecessorTask|
          # 3.2.1.
          if (iAssignmentInfo[iPredecessorTask].FinalAssignment == nil)
            # 3.2.1.1.
            lAllPredecessorsAssigned = false
            # 3.2.1.2.
            break
          end
        end
        # 3.3.
        if (lAllPredecessorsAssigned)
          # 3.3.1.
          lNewTaskPaths[iSuccessorTask] = nil
        end
      end
      # 4.
      if (iCurrentPathNode.TaskPaths[iTask] == nil)
        # 4.1.
        iCurrentPathNode.TaskPaths[iTask] = TaskAssignmentPossibilities_Type.new(iInitialImportance)
      end
      # 5.
      # 5.1.
      # 6.
      # 6.1.
      lNewMinimalImportance = iCurrentPathNode.PathMinimalImportance
      if ((iCurrentPathNode.PathMinimalImportance == nil) or
          (iCurrentPathNode.PathMinimalImportance > iInitialImportance))
        lNewMinimalImportance = iInitialImportance
      end
      # 7.
      if (iConsequences.MaximalShiftedImportance > lNewMinimalImportance)
        # 7.1.
        iCurrentPathNode.TaskPaths[iTask].Iterations[iIterationNbr] = PathNode_Type.new(iConsequences, lNewMinimalImportance, lNewTaskPaths)
        # 7.2.
        return false
      # 8.
      else
        # 8.1.
        iCurrentPathNode.TaskPaths[iTask].Iterations[iIterationNbr] = PathNode_Type.new(nil, lNewMinimalImportance, lNewTaskPaths)
        # 8.2.
        return true
      end
    end
    
  end
  
end
