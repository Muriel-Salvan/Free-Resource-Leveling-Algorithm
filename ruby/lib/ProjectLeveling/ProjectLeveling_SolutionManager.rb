#--
# Copyright (c) 2007 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module ProjectLeveling

  # Solution manager
  class SolutionManager
  
    # Class representing an assigned task
    class AssignedTaskID_Type
    
      #   Task
      attr_accessor :Task
      
      #   Integer
      attr_accessor :IterationNbr
      
      # Constructor
      #
      # Parameters::
      # * *iTask* (_Task_): The task
      # * *iIterationNbr* (_Integer_): The iteration number
      def initialize(iTask, iIterationNbr)
        @Task = iTask
        @IterationNbr = iIterationNbr
      end
      
    end
    
    # Class representing a solution for a task's assignment
    class TaskAssignmentSolution_Type < Hash
    
      #   Date
      attr_accessor :StartDate
      
      #   Date
      attr_accessor :EndDate
      
      #   Integer
      attr_accessor :EndDateHours
      
      # Constructor
      def initialize
        @StartDate = nil
        @EndDate = nil
        @EndDateHours = nil
        super
      end
      
      # Set up from an existing map of resources slots
      #
      # Parameters::
      # * *iResourcesSlots* (<em>map<Date,map<Resource,Integer>></em>): The resources slot
      # * *iMinStartDate* (_Date_): The minimal start date (do not consider dates before this one)
      def setFromExistingResourcesSlots(iResourcesSlots, iMinStartDate)
        iResourcesSlots.each do |iDate, iResourcesInfo|
          if (iDate >= iMinStartDate)
            self[iDate] = iResourcesInfo
          end
        end
      end
      
      # Update the dates given a new added date and its corresponding resources availability
      #
      # Parameters::
      # * *iDate* (_Date_): The date added
      # * *iResourcesInfo* (<em>map<Resource,Integer></em>): The resources availability
      def updateDates(iDate, iResourcesInfo)
        if (@StartDate == nil)
          # First time there is an affectation
          @StartDate = iDate
          @EndDate = iDate
          @EndDateHours = 0
          iResourcesInfo.each do |iResource, iHours|
            @EndDateHours += iHours
          end
        elsif (@StartDate > iDate)
          # Different start date
          @StartDate = iDate
        elsif (@EndDate < iDate)
          # Different end date
          @EndDate = iDate
          @EndDateHours = 0
          iResourcesInfo.each do |iResource, iHours|
            @EndDateHours += iHours
          end
        end
      end
      
      # Redefine the affectation method to fill in start date, end date and end date hours
      #
      # Parameters::
      # * *iKey* (_Date_): The day to assign resources to.
      # * *iObject* (<em>map<Resource,Integer></em>): The map of resources to assign on this day, along with their working hours
      def []=(iKey, iObject)
        # Change dates if needed
        updateDates(iKey, iObject)
        # Call inherited method
        super
      end
      
    end
    
    # Class storing an assignment info
    class AssignmentInfo_Type < Hash
      
      # Redefine the clone method, as values have to be cloned also
      #
      # Return::
      # * <em>AssignmentInfo_Type</em>: The clone
      def clone
        rClone = AssignmentInfo_Type.new
        
        self.each do |iTask, iAssignmentInfoPerTask|
          rClone[iTask] = iAssignmentInfoPerTask.clone
        end
        
        return rClone
      end
      
    end
    
    # Class storing assignment information per task
    class AssignmentInfoPerTask_Type
    
      #   map< Date, map< Resource, Integer > >
      attr_accessor :AvailableResourcesSlots
      
      #   Integer
      attr_accessor :AvailableHours
      
      #   map< Date, map< Resource, Integer > >
      attr_accessor :FinalAssignment
      
      # Measures of each assignment strategy
      #   map< AssignmentStrategy, [ Measure, MeasureMax ] >
      attr_accessor :FinalAssignmentMeasures
      
      #   Date
      attr_accessor :MinStartDate
      
      #   Date
      attr_accessor :MinEndDate
      
      #   Integer
      attr_accessor :MinEndDateHours
      
      #   Date
      attr_accessor :MaxEndDate
      
      #   Integer
      attr_accessor :Importance
      
      #   Integer
      attr_accessor :NonOptimalAccumulatedDelay
      
      #   map< Resource, ResourceBuffers_Type >
      attr_accessor :ResourcesBuffers
      
      # Redefine the clone method, as some attributes have to be cloned also
      #
      # Return::
      # * <em>AssignmentInfoPerTask_Type</em>: The clone
      def clone
        rClone = AssignmentInfoPerTask_Type.new
        
        rClone.AvailableResourcesSlots = {}
        @AvailableResourcesSlots.each do |iDate, iResourcesMap|
          rClone.AvailableResourcesSlots[iDate] = iResourcesMap.clone
        end
        rClone.AvailableHours = @AvailableHours
        if (@FinalAssignment != nil)
          rClone.FinalAssignment = @FinalAssignment.clone
        else
          rClone.FinalAssignment = nil
        end
        if (@FinalAssignmentMeasures != nil)
          rClone.FinalAssignmentMeasures = @FinalAssignmentMeasures.clone
        else
          rClone.FinalAssignmentMeasures = nil
        end
        rClone.MinStartDate = @MinStartDate
        rClone.MinEndDate = @MinEndDate
        rClone.MinEndDateHours = @MinEndDateHours
        rClone.MaxEndDate = @MaxEndDate
        rClone.Importance = @Importance
        rClone.NonOptimalAccumulatedDelay = @NonOptimalAccumulatedDelay
        rClone.ResourcesBuffers = @ResourcesBuffers.clone
        
        return rClone
      end
      
    end

    # The class storing used/unused counters for a resource assigned to a task
    class ResourceBuffers_Type
    
      #   Integer
      attr_accessor :Used
      
      #   Integer
      attr_accessor :Unused
      
      # Constructor
      def initialize
        @Used = 0
        @Unused = 0
      end
      
    end

    # Basic class for assignment strategies
    class AssignmentStrategy
      
      #   Integer
      attr_accessor :Coefficient
      
      # Constructor
      #
      # Parameters::
      # * *iCoefficient* (_Integer_): How important this strategy is ?
      def initialize(iCoefficient = 50)
        @Coefficient = iCoefficient
      end
      
    end

    # Assignment strategy of 1 resource per task
    class AS1ResPerTask < AssignmentStrategy
      
      # Assign the task to resources for day iDay.
      #
      # Parameters::
      # * *iDay* (_Date_): The day we want to assign resources for
      # * *iTask* (_Task_): The task we want to assign resources to
      # * *iCurrentAssignment* (<em>map<Date,map<Resource,Integer>></em>): The assignment already made for previous days
      # * *iAvailableResourcesForThisDay* (<em>map<Resource,Hours></em>): The number of hours per resource that can be assigned on day iDay.
      # * *iAvailableResources* (<em>map<Resource,Hours></em>): The number of hours per resource that can be assigned for the remaining days of iTask.
      # * *iAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The assignment info
      # * *iMaxHoursNumber* (_Integer_): The maximal number of hours we have to assign
      # Return::
      # * <em>map<Resource,Integer></em>: The resources assigned to iTask on day iDay
      def assignDay(iDay, iTask, iCurrentAssignment, iAvailableResourcesForThisDay, iAvailableResources, iAssignmentInfo, iMaxHoursNumber)
        # The result
        rDayAssignment = {}
        
        iTaskAssignmentInfo = iAssignmentInfo[iTask]
        if (iCurrentAssignment.empty?)
          # iDay is the first day.
          # Find the resource that has the biggest availability for the entire task (not
          # just iDay).
          lMaxAvailableHours = nil
          lChosenResource = nil
          iAvailableResources.each do |iResource, iAvailableHours|
            if ((lMaxAvailableHours == nil) or
                (lMaxAvailableHours < iAvailableResources[iResource]))
              lMaxAvailableHours = iAvailableResources[iResource]
              lChosenResource = iResource
            end
          end
          # Now assign lChosenResource (if it has some hours)
          if (iAvailableResourcesForThisDay.has_key?(lChosenResource))
            if (iAvailableResourcesForThisDay[lChosenResource] <= iMaxHoursNumber)
              rDayAssignment[lChosenResource] = iAvailableResourcesForThisDay[lChosenResource]
            else
              rDayAssignment[lChosenResource] = iMaxHoursNumber
            end
          end
        else
          # Among the resources that were already used, try to assign the one that has
          # the most available hours.
          lMaxAvailableHours = nil
          lChosenResource = nil
          iCurrentAssignment.each do |iDay, iDayAssignment|
            iDayAssignment.each do |iResource, iAssignedHours|
              if ((lMaxAvailableHours == nil) or
                  (lMaxAvailableHours < iAvailableResources[iResource]))
                lMaxAvailableHours = iAvailableResources[iResource]
                lChosenResource = iResource
              end
            end
          end
          # Now assign lChosenResource (if it has some hours)
          if (iAvailableResourcesForThisDay.has_key?(lChosenResource))
            if (iAvailableResourcesForThisDay[lChosenResource] <= iMaxHoursNumber)
              rDayAssignment[lChosenResource] = iAvailableResourcesForThisDay[lChosenResource]
            else
              rDayAssignment[lChosenResource] = iMaxHoursNumber
            end
          end
        end
        
        return rDayAssignment
      end
      
      # Measure the assignment
      #
      # Parameters::
      # * *iTask* (_Task_): The task we want to assign resources to
      # * *iCurrentAssignment* (<em>map<Date,map<Resource,Integer>></em>): The assignment already made for previous days
      # * *iAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The assignment info
      # Return::
      # * _Integer_: The measurement
      # * _Integer_: The maximal value the measurement could have if it was perfect
      def measure(iTask, iCurrentAssignment, iAssignmentInfo)
        # We count the number of different resources assigned
        # map< Resource, nil >
        lAssignedResources = {}
        iCurrentAssignment.each do |iDay, iResourcesMap|
          iResourcesMap.each do |iResource, iAssignedHours|
            lAssignedResources[iResource] = nil
          end
        end
        lMaxNumber = iTask.ResourcesMap.size
        return lMaxNumber - lAssignedResources.size + 1, lMaxNumber
      end
      
    end
    
    if ($Debug)

      # Display a detailed assignment
      #
      # Parameters::
      # * *iAssignment* (<em>map<Date,map<Resource,Integer>></em>): The assignment
      # * *iMinimalStartDate* (_Date_): The minimal start date to consider for the assignment. If nil, consider all dates. [optional = nil]
      # * *iStrPrefix* (_String_): The string prefix for display. [optional = '']
      def self.displayDetailedAssignment(iAssignment, iMinimalStartDate = nil, iStrPrefix = '')
        iAssignment.keys.sort.each do |iDay|
          if ((iMinimalStartDate == nil) or
              (iDay >= iMinimalStartDate))
            lDayAssignment = iAssignment[iDay]
            lStrSchedule = []
            lDayAssignment.each do |iResource, iWorkingHours|
              lStrSchedule << "#{iResource.Name}(#{iWorkingHours})"
            end
            puts "#{iStrPrefix}+-#{iDay}: #{lStrSchedule.join(', ')}"
          end
        end
      end

      # Display an assigned tasks' list (debug only)
      #
      # Parameters::
      # * *iAssignedTasksList* (<em>list<AssignedTaskID_Type></em>): The tasks list
      # * *iAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The assignment info that gives importances (can be nil)
      # * *iStrPrefix* (_String_): A prefix to add to each line [optional = '']
      def self.displayAssignedTasksList(iAssignedTasksList, iAssignmentInfo, iStrPrefix = '')
        iAssignedTasksList.each do |iAssignedTask|
          if (iAssignmentInfo != nil)
            puts "#{iStrPrefix}- [#{iAssignedTask.Task.Name}, #{iAssignedTask.IterationNbr}] (I=#{iAssignmentInfo[iAssignedTask.Task].Importance} P=#{iAssignedTask.Task.Priority})"
          else
            puts "#{iStrPrefix}- [#{iAssignedTask.Task.Name}, #{iAssignedTask.IterationNbr}] (P=#{iAssignedTask.Task.Priority})"
          end
        end
      end
      
      # Get an assigned tasks' list as a single string (debug only)
      #
      # Parameters::
      # * *iAssignedTasksList* (<em>list<AssignedTaskID_Type></em>): The tasks list
      # Return::
      # * _String_: The assigned tasks list for display
      def self.formatAssignedTasksList(iAssignedTasksList)
        rStrList = []
        iAssignedTasksList.each do |iAssignedTask|
          rStrList << "[#{iAssignedTask.Task.Name}, #{iAssignedTask.IterationNbr}]"
        end
        return rStrList.join(', ')
      end
      
      # Display an assignment info
      #
      # Parameters::
      # * *iAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The assignment info
      # * *iDetailed* (_Boolean_): Do we display all detail of the assignment ?
      def self.displayAssignmentInfo(iAssignmentInfo, iDetailed = false)
        # Sort by name
        lNamesMap = {}
        iAssignmentInfo.each do |iTask, iTaskAssignmentInfo|
          lNamesMap[iTask.Name] = [ iTask, iTaskAssignmentInfo ]
        end
        lIdxTask = 0
        lNamesMap.keys.sort.each do |iTaskName|
          lStrFollowNextTask = '| '
          if (lIdxTask == lNamesMap.size - 1)
            lStrFollowNextTask = '  '
          end
          iTask, iTaskAssignmentInfo = lNamesMap[iTaskName]
          if (iTaskAssignmentInfo.FinalAssignment != nil)
            lFinalizedMark = '*'
          else
            lFinalizedMark = ' '
          end
          puts "+-#{iTask.Name} (I=#{iTaskAssignmentInfo.Importance} P=#{iTask.Priority} S=#{iTask.Sizing}) #{lFinalizedMark} - [#{iTaskAssignmentInfo.MinStartDate}..#{iTaskAssignmentInfo.MinEndDate}(#{iTaskAssignmentInfo.MinEndDateHours})..#{iTaskAssignmentInfo.MaxEndDate}] Avl=#{iTaskAssignmentInfo.AvailableHours}"
          if (iDetailed)
            if (iTaskAssignmentInfo.FinalAssignment != nil)
              puts "#{lStrFollowNextTask}+-Final resources assignment:"
              SolutionManager.displayDetailedAssignment(iTaskAssignmentInfo.FinalAssignment, nil, "#{lStrFollowNextTask}  ")
            else
              puts "#{lStrFollowNextTask}+-Resources availability:"
              SolutionManager.displayDetailedAssignment(iTaskAssignmentInfo.AvailableResourcesSlots, iTaskAssignmentInfo.MinStartDate, "#{lStrFollowNextTask}| ")
              puts "#{lStrFollowNextTask}+-Resources buffers:"
              iTaskAssignmentInfo.ResourcesBuffers.each do |iResource, iBufferInfo|
                puts "#{lStrFollowNextTask}  +-#{iResource.Name}: #{iBufferInfo.Used} used and #{iBufferInfo.Unused} unused."
              end
            end
          end
          lIdxTask += 1
        end
      end

    end
    
    # Iterate on a ways to assign the task to its available resources.
    #
    # Parameters::
    # * *iTask* (_Task_): The task we want to assign
    # * *iAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The current availability of resources
    # * *iAssignmentStrategies* (<em>list<AssignmentStrategy></em>): The list of assignment strategies to consider
    # * *CodeBlock*: The code block to call when iteration is ok. It takes map<Resource,Integer> as argument: The list of resources assigned, along with their working hours
    def self.iterateOverAssignments(iTask, iAssignmentInfo, iAssignmentStrategies)
      # TODO !!! It is possible that the iTask was already validated (iAssignmentInfo[iTask].FinalAssignment not None). In this case, just enter the iteration code without computing any solution.
      # Try to find several ways to assign iTask
      lAssignmentInfoForTask = iAssignmentInfo[iTask]
      # Compute the maximal coefficient
      lMaxCoeff = 0
      # and the measures (how much the assignment responds to the coefficients)
      iAssignmentStrategies.each do |iAS|
        if (iAS.Coefficient > lMaxCoeff)
          lMaxCoeff = iAS.Coefficient
        end
      end
      # The number of hours available per resource.
      # map< Resource, Integer >
      lAvailableResources = iTask.ResourcesMap.clone
      # The assignment that we build day after day
      # map< Date, map< Resource, Hours > >
      lChosenAssignment = TaskAssignmentSolution_Type.new
      # !!! Make sure lChosenAssignment[D] objects are never modified after being
      # affected. This is due to the fact that lChosenAssignment.Start/EndDate/Hours
      # are computed only during affectation. If it is needed to still modify it,
      # don't forget to update lChosenAssignment.Start/EndDate/Hours accordingly.
      
      # The measures associated to each strategy
      # map< AssignmentStrategy, [ Measure, MeasureMax ] >
      lChosenAssignmentMeasures = {}
      # The total number of hours assigned. This is used to ensure we stop once the task's sizing
      # has been reached.
      lTotalAssignedHours = 0
      # Assign day by day, and adapt the assignment based on the measures and coefficients
      # of each parameter.
      (lAssignmentInfoForTask.MinStartDate .. lAssignmentInfoForTask.MaxEndDate).each do |iDay|
        # Decide which parameter will be chosen based on the measures and the coefficient
        # The following values represent the distance between what is measured and what
        # we want.
        #   == 0: We have what we want for this parameters.
        #   > 0: We have less than what we want
        #   < 0: We have more than what we want
        # The goal is to have all those measures <= 0
        # In case of several distances > 0, we will choose to improve the most important
        # one (relatively to its coefficient also).
        lMaxDistance = nil
        lChosenAS = nil
        iAssignmentStrategies.each do |iAS|
          lCoeff = iAS.Coefficient
          lDistance = 0
          if (lChosenAssignmentMeasures.has_key?(iAS))
            # We already have a measure of previous assignments
            lDistance = lCoeff*lCoeff - (lChosenAssignmentMeasures[iAS][0]*lMaxCoeff*lCoeff)/lChosenAssignmentMeasures[iAS][1]
          else
            # We already have a measure of previous assignments
            lDistance = lCoeff*lCoeff
            lChosenAssignmentMeasures[iAS] = [0, 0]
          end
          if ((lMaxDistance == nil) or
              (lDistance < lMaxDistance))
            lChosenAS = iAS
            lDistance = lMaxDistance
          end
        end
        # We compute the available hours of each resource for day iDay only.
        # Take care of resources' availability.
        # map< Resource, Hours >
        lAvailableResourcesForThisDay = {}
        lAvailableResources.each do |iResource, iAvailableHours|
          if (iResource.AvailabilityMap.has_key?(iDay))
            # Take the minimal value between:
            # * the available hours (the number of hours the resource can work on the task),
            # * the working hours (the resources' holidays),
            # * the availibility of the resource for this day (does the resource already work on other tasks ?)
            if ((lAssignmentInfoForTask.AvailableResourcesSlots.has_key?(iDay)) and
                (lAssignmentInfoForTask.AvailableResourcesSlots[iDay].has_key?(iResource)))
              if (iResource.AvailabilityMap[iDay] < iAvailableHours)
                lAvailableResourcesForThisDay[iResource] = iResource.AvailabilityMap[iDay]
              else
                lAvailableResourcesForThisDay[iResource] = iAvailableHours
              end
              if (lAssignmentInfoForTask.AvailableResourcesSlots[iDay][iResource] < lAvailableResourcesForThisDay[iResource])
                lAvailableResourcesForThisDay[iResource] = lAssignmentInfoForTask.AvailableResourcesSlots[iDay][iResource]
              end
              # If the resource has no availibility, delete its entry.
              if (lAvailableResourcesForThisDay[iResource] == 0)
                lAvailableResourcesForThisDay.delete(iResource)
              end
            end
          end
        end
        if (!lAvailableResourcesForThisDay.empty?)
          # lChosenAS is the assignment strategy we choose to assign on the day iDay
          lDayAssignment = lChosenAS.assignDay(iTask, iDay, lChosenAssignment, lAvailableResourcesForThisDay, lAvailableResources, iAssignmentInfo, iTask.Sizing - lTotalAssignedHours)
          if ((lDayAssignment != nil) and
              (!lDayAssignment.empty?))
            lChosenAssignment[iDay] = lDayAssignment
            # Update the available hours per resource
            lChosenAssignment[iDay].each do |iResource, iAssignedHours|
              # TODO: In debug mode, add tests to check values (exist and never greater). If these checks fail, it means that the assignment strategy class has a bug, and assigns resources it shouldn't.
              lAvailableResources[iResource] -= iAssignedHours
              lTotalAssignedHours += iAssignedHours
            end
          end
          # TODO: In debug mode, check that the total assigned hours does not exceed the sizing. Otherwise it would mean the assignment strategy has assigned more resources than needed.
          # Then we re-evaluate the measures: set lMeasures and lMeasuresMax based on the
          # assignment from lAssignmentInfoForTask.MinStartDate to iDay only.
          lIdxCoeff = 0
          iAssignmentStrategies.each do |iAS|
            lChosenAssignmentMeasures[iAS][0], lChosenAssignmentMeasures[iAS][1] = iAS.measure(iTask, lChosenAssignment, iAssignmentInfo)
          end
          # Stop the loop once the complete sizing of the task has been met.
          if (lTotalAssignedHours >= iTask.Sizing)
            break
          end
        end
      end
      # We have built a solution. Now call the process that challenge this assignment.
      # TODO: Use a real iteration number instead of 0.
      # TODO: Skip the iterations below iMinimalIterationNbr.
      # TODO: Set iLastIteration correctly
      yield(lChosenAssignment, lChosenAssignmentMeasures, 0, true)
      # And now we go on the next trial if we have. Otherwise we simply exit.
      # TODO: loop again.
    end
    
    # Main recursive method assigning tasks to resources
    #
    # Parameters::
    # * *iCurrentTasksList* (<em>list<AssignedTaskID_Type></em>): The list of couples (task, assignment iteration number), sorted by importance, that we want to assign to resources. It can be modified internally.
    # * *iAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The availability of resources we can use for this assignment
    # * *iCurrentPathNode* (<em>PathNode_Type</em>): The current node of the branch in the paths tree
    # * *iAssignmentStrategies* (<em>list<AssignmentStrategy></em>): The list of assignment strategies to consider
    # Return::
    # * <em>list<AssignmentInfo_Type></em>: The list of possible assignments
    def self.findAssignmentForTaskList(iCurrentTasksList, iAssignmentInfo, iCurrentPathNode, iAssignmentStrategies)
      # 1.
      lTasksListToTry = iCurrentTasksList
      # 2.
      while (true)
        # 2.1.
        if ($Debug)
          puts ''
          puts '----- Find assignment for the following assigned tasks list:'
          SolutionManager.displayAssignedTasksList([lTasksListToTry[0]], iAssignmentInfo, 'Assign>')
          SolutionManager.displayAssignedTasksList(lTasksListToTry[1..-1], iAssignmentInfo, '       ')
        end
        lTask = lTasksListToTry[0].Task
        lRemainingTasksList = lTasksListToTry[1..-1]
        lIterationNumber = lTasksListToTry[0].IterationNbr
        # The maximal number of iterations that we try
        lMaxIterations = 3
        rPossibleAssignments = []
        lBlockingTask = nil
        # 2.2.
        if ((iCurrentPathNode.TaskPaths[lTask] != nil) and
            (iCurrentPathNode.TaskPaths[lTask].Iterations.has_key?(lIterationNumber)))
          if ($Debug)
            puts "[#{lTask.Name}, #{lIterationNumber}] - This assignment was already performed. Skip directly to the next task."
          end
          # 2.2.1.
          lSubPossibleAssignments = SolutionManager.findAssignmentForTaskList(lRemainingTasksList, iCurrentPathNode.TaskPaths[lTask].Iterations[lIterationNumber].AssignmentInfo, iCurrentPathNode.TaskPaths[lTask].Iterations[lIterationNumber], iAssignmentStrategies)
          # 2.2.2.
          if (!lSubPossibleAssignments.empty?)
            # 2.2.2.1.
            rPossibleAssignments += lSubPossibleAssignments
          end
        # 2.3.
        else
          # 2.3.1.
          lAllDirectFailures = true
          lInitialImportance = iAssignmentInfo[lTask].Importance
          # 2.3.2.
          SolutionManager.iterateOverAssignments(lTask, iAssignmentInfo, iAssignmentStrategies) do |iPossibleAssignment, iPossibleAssignmentMeasures, iIterationNbr, iLastIteration|
            # 2.3.2.1.
            lDirectSuccess = SolutionManager.tryPossibleSolution(lTask, iIterationNbr, iAssignmentInfo, iPossibleAssignment, iPossibleAssignmentMeasures, rPossibleAssignments, lRemainingTasksList, lInitialImportance, iCurrentPathNode, iAssignmentStrategies)
            # 2.3.2.2.
            if (lDirectSuccess)
              # 2.3.2.2.1.
              lAllDirectFailures = true
            end
            # 2.3.2.3.
            if ((iLastIteration == true) or
                (iIterationNbr >= lMaxIterations - 1))
              if ($Debug)
                puts "[#{lTask.Name}, #{iIterationNbr}] - Maximal iteration encountered: break the loop of iterations."
              end
              # 2.3.2.3.1.
              break
            end
          end
          # 2.3.3.
          if (lAllDirectFailures)
            # 2.3.3.1.
            iCurrentPathNode.TaskPaths[lTask].RemainingTasks = lRemainingTasksList
            # 2.3.3.2.
            iCurrentPathNode.TaskPaths[lTask].SolutionFound = false
          # 2.3.4.
          else
            # 2.3.4.1.
            iCurrentPathNode.TaskPaths[lTask].SolutionFound = true
          end
        end
        # End of all the iterations
        if ($Debug)
          puts "[#{lTask.Name}] - Ending iterations."
        end
        # 2.4.
        if (rPossibleAssignments.empty?)
          if ($Debug)
            puts "[#{lTask.Name}] - No optimal assignment found. Let's try a possible better path."
          end
          # 2.4.1.
          iCurrentPathNode.TaskPaths[lTask].ShiftedTasksList = nil
          iCurrentPathNode.TaskPaths[lTask].AlreadyTriedSearches = []
          # 2.4.2.
          PathsManager.computeShiftedTasksList(lTask, iCurrentPathNode, iCurrentTasksList.size)
          # 2.4.3.
          lNewTasksList = PathsManager.findPossibleBetterPathForTask(lTask, iCurrentPathNode, lTasksListToTry)
          # 2.4.4.
          if (lNewTasksList != nil)
            if ($Debug)
              puts "[#{lTask.Name}] - Possible better path found: #{self.formatAssignedTasksList(lNewTasksList)}. Replace the tasks list and try again."
            end
            # 2.4.4.1.
            lTasksListToTry = lNewTasksList
            # 2.4.4.2.
          # 2.4.5.
          else
            if ($Debug)
              puts "[#{lTask.Name}] - No possible better path for now. Let's hope upper tasks will find one."
            end
            # 2.4.5.1.
            return []
          end
        # 2.5.
        else
          if ($Debug)
            puts "[#{lTask.Name}] - #{rPossibleAssignments.size} assignments were successful."
          end
          # 2.5.1.
          return rPossibleAssignments
        end
      end
    end

    # Try a solution
    #
    # Parameters::
    # * *iTask* (_Task_): The task that we are trying to assign now.
    # * *iIterationNbr* (_Integer_): The iteration number of this assignment.
    # * *iAssignmentInfo* (<em>AssignmentInfo_Type</em>): The assignment context in which we want to assign the task.
    # * *iPossibleAssignment* (<em>TaskAssignmentSolution_Type</em>): The possible assignment for task iTask that we want to try.
    # * *iPossibleAssignmentMeasures* (<em>map<AssignmentStrategy,[Integer,Integer]></em>): Measures of the assignment.
    # * *ioPossibleAssignments* (<em>list<AssignmentInfo_Type></em>): The list of possible assignments that we got after assigning iTask and all subsequent tasks.
    # * *iRemainingTasksList* (<em>Branch_Type</em>): The remaining list of tasks to assign.
    # * *iInitialTaskImportance* (_Integer_): The initial task's importance.
    # * *iCurrentPathNode* <em>(PathNode_Type</em>): The current node in the already tried paths' tree.
    # * *iAssignmentStrategies* (<em>list<AssignmentStrategy></em>): The list of assignment strategies to consider
    # Return::
    # * _Boolean_: Has this possible solution been optimal for this task ?
    def self.tryPossibleSolution(iTask, iIterationNbr, iAssignmentInfo, iPossibleAssignment, iPossibleAssignmentMeasures, ioPossibleAssignments, iRemainingTasksList, iInitialImportance, iCurrentPathNode, iAssignmentStrategies)
      if ($Debug)
        puts ''
        puts "[#{iTask.Name}, #{iIterationNbr}] - Possible assignment to be tested:"
        SolutionManager.displayDetailedAssignment(iPossibleAssignment)
        puts "[#{iTask.Name}, #{iIterationNbr}] - Current assignment info:"
        SolutionManager.displayAssignmentInfo(iAssignmentInfo, true)
      end
      # 1.
      lConsequences = PathsManager::ShiftedTaskConsequences_Type.new
      # 2.
      if (iAssignmentInfo[iTask].FinalAssignment == nil)
        # 2.1.
        lNewAssignmentInfo = iAssignmentInfo.clone
        # 2.2.
        TaskAssignmentManager.assignPossibleSolution(iTask, [], iPossibleAssignment, iPossibleAssignmentMeasures, iCurrentPathNode.PathMinimalImportance, lNewAssignmentInfo, lConsequences, iAssignmentStrategies)
        # 2.3.
        if (lConsequences.PossibleConsequence)
          if ($Debug)
            puts "[#{iTask.Name}, #{iIterationNbr}] - Possible assignment is ok, shifting priority #{lConsequences.MaximalShiftedImportance}. Resulting assignment info:"
            SolutionManager.displayAssignmentInfo(lNewAssignmentInfo)
          end
          # 2.3.1.
          ImportanceManager.updateImportance(iTask, lNewAssignmentInfo)
        end
      # 3.
      else
        # 3.1.
        lNewAssignmentInfo = iAssignmentInfo
      end
      # 4.
      lPathOptimal = PathsManager.completeTriedPath(iCurrentPathNode, iTask, iIterationNbr, lConsequences, iInitialImportance, lNewAssignmentInfo)
      # 5.
      if (!lPathOptimal)
        if ($Debug)
          puts "[#{iTask.Name}, #{iIterationNbr}] - The path is not optimal. Just ignore this iteration."
        end
        # 5.1.
        if (lConsequences.PossibleConsequence)
          # 5.1.1.
          iCurrentPathNode.TaskPaths[iTask].Iterations[iIterationNbr].AssignmentInfo = lNewAssignmentInfo
        end
        # 5.2.
        return false
      # 6.
      else
        if ($Debug)
          puts "[#{iTask.Name}, #{iIterationNbr}] - Paths manager granted this path was optimized. Go on with the next task."
        end
        # 6.1.
        if (!iRemainingTasksList.empty?)
          # 6.1.1.
          lSubPossibleAssignments = SolutionManager.findAssignmentForTaskList(iRemainingTasksList, lNewAssignmentInfo, iCurrentPathNode.TaskPaths[iTask].Iterations[iIterationNbr], iAssignmentStrategies)
          # 6.1.2.
          if (!lSubPossibleAssignments.empty?)
            if ($Debug)
              puts "[#{iTask.Name}, #{iIterationNbr}] - Recursive call returned #{lSubPossibleAssignments.size} possible assignments. Add them to our list."
            end
            # 6.1.2.1.
            ioPossibleAssignments.concat(lSubPossibleAssignments)
          # 6.1.3.
          elsif (ioPossibleAssignments.empty?)
            if ($Debug)
              puts "[#{iTask.Name}, #{iIterationNbr}] - Recursive call did not return any successful assignment."
            end
            # 6.1.3.1.
            lAllPathsConsidered = true
            # 6.1.3.2.
            iCurrentPathNode.TaskPaths[iTask].Iterations[iIterationNbr].TaskPaths.each do |iNextPossibleTask, iTaskPathInfo|
              # 6.1.3.2.1.
              if (iTaskPathInfo == nil)
                # 6.1.3.2.1.1.
                lAllPathsConsidered = false
                # 6.1.3.2.1.2.
                break
              end
            end
            # 6.1.3.3.
            if (lAllPathsConsidered)
              # 6.1.3.3.1.
              iCurrentPathNode.TaskPaths[iTask].Iterations[iIterationNbr].AssignmentInfo = nil
            # 6.1.3.4.
            else
              # 6.1.3.4.1.
              iCurrentPathNode.TaskPaths[iTask].Iterations[iIterationNbr].AssignmentInfo = lNewAssignmentInfo
            end
          # 6.1.4.
          else
            # 6.1.4.1.
            iCurrentPathNode.TaskPaths[iTask].Iterations[iIterationNbr].AssignmentInfo = nil
          end
        # 6.2.
        else
          if ($Debug)
            puts "[#{iTask.Name}, #{iIterationNbr}] - No more tasks after this one. The assignment is forcefully possible. Add it to our list of possible assignments."
          end
          # 6.2.1.
          ioPossibleAssignments << lNewAssignmentInfo
        end
        # 6.3.
        return true
      end
    end

    # Assign a task to its resources
    #
    # Parameters::
    # * *iTask* (Task): The task that we want to assign to the last resources
    # * *iTasksListToIgnore* (<em>list<Task></em>): The tasks list we have to ignore due to a recursive call [default to an empty list]
    # * *iMinimalPathImportance* (_Integer_): The minimal importance of already assigned tasks.
    # * *ioAssignmentInfo* (<em>map<Task, AssignmentInfoPerTask_Type></em>): The current availability of resources to modify
    # * *ioConsequences* (<em>ShiftedTaskConsequences_Type</em>): The consequences to fill.
    # * *iAssignmentStrategies* (<em>list<AssignmentStrategy></em>): The list of assignment strategies to consider
    def self.assignCompleteTask(iTask, iTasksListToIgnore, iMinimalPathImportance, ioAssignmentInfo, ioConsequences, iAssignmentStrategies)
      # 1.
      # Build lUniqueSolution based on the available resources.
      lUniqueSolution = TaskAssignmentSolution_Type.new
      lUniqueSolution.setFromExistingResourcesSlots(ioAssignmentInfo[iTask].AvailableResourcesSlots, ioAssignmentInfo[iTask].MinStartDate)
      # The measures of the solution
      #   map< AssignmentStrategy, [ Integer, Integer ] >
      lUniqueSolutionMeasures = {}
      iAssignmentStrategies.each do |iAS|
        lUniqueSolutionMeasures[iAS] = iAS.measure(iTask, lUniqueSolution, ioAssignmentInfo)
      end
      # 2.
      TaskAssignmentManager.assignPossibleSolution(iTask, iTasksListToIgnore + [iTask], lUniqueSolution, lUniqueSolutionMeasures, iMinimalPathImportance, ioAssignmentInfo, ioConsequences, iAssignmentStrategies)
    end

  end

end
