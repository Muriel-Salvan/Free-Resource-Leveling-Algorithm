#--
# Copyright (c) 2007 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++
# Usage:
# ruby -I../lib -w run.rb

require 'test/unit'
require 'ProjectLeveling/ProjectLeveling'

module ProjectLeveling

  # Test unit
  class TestProjectLeveling < Test::Unit::TestCase

    # Execute a test
    #
    # Parameters::
    # * *iTasksList* (<em>list<Task></em>): The tasks list
    # * *iProject* (_Project_): The project information
    # * *iExpectedResult* (<em>map< Task, map< Date, map< Resource, Integer > > ></em>): The expected result (the hours worked per resource, per day, per task.
    def executeTest(iTasksList, iProject, iExpectedResult)
      # Prepare additional information
      Task.populatePredecessors(iTasksList)
      Task.populateSharingResourcesTasksID(iTasksList)
      # Level everything
      lAssignmentInfo, lErrorList = ProjectLeveling::levelProject(iTasksList, iProject)
      lMessages = []
      # Check there is a result
      if (lAssignmentInfo == nil)
        lMessages << 'No assignment was returned by the algorithm'
      end
      # Check there are no error messages
      if (lErrorList != nil)
        lMessages << "#{lErrorList.size} errors were returned by the algorithm:"
        lIdx = 0
        lErrorList.each do |iErrorDetail|
          lMessages << "Error #{lIdx} - Task #{iErrorDetail[0].Name}: #{iErrorDetail[1]}"
          lIdx += 1
        end
      end
      if (lAssignmentInfo != nil)
        # Check there are the same number of tasks
        if (iExpectedResult.size != lAssignmentInfo.size)
          lMessages << "Expected #{iExpectedResult.size} tasks to be leveled, but returned #{lAssignmentInfo.size}"
        end
        # For each task, check the assignment
        iExpectedResult.each do |iTask, iExpectedTaskAssignmentInfo|
          # Check the task is present
          if (lAssignmentInfo[iTask] == nil)
            lMessages << "[#{iTask.Name}] - Expecting task to be leveled, but the algorithm did not returned it."
          else
            lReturnedTaskAssignmentInfo = lAssignmentInfo[iTask].FinalAssignment
            # Check the task was finalized
            if (lReturnedTaskAssignmentInfo == nil)
              lMessages << "[#{iTask.Name}] - Task was returned but not finalized."
            else
              # Check the assignment: same number of days
              if (iExpectedTaskAssignmentInfo.size != lReturnedTaskAssignmentInfo.size)
                lMessages << "[#{iTask.Name}] - Task should have #{iExpectedTaskAssignmentInfo.size} days assigned, but the algorithm returned #{lReturnedTaskAssignmentInfo.size}"
              end
              # Check each day of the expected assignment
              iExpectedTaskAssignmentInfo.each do |iDay, iResourcesAssignment|
                # Check the day exists in returned assignment
                if (lReturnedTaskAssignmentInfo[iDay] == nil)
                  lMessages << "[#{iTask.Name}] - [#{iDay}] - Task should have assigned resources on this day, but none returned"
                else
                  # Check the number of resources assigned on day iDay
                  if (iResourcesAssignment.size != lReturnedTaskAssignmentInfo[iDay].size)
                    lMessages << "[#{iTask.Name}] - [#{iDay}] - Task should have #{iResourcesAssignment.size} resources assigned on this day, but the algorithm returned #{lReturnedTaskAssignmentInfo[iDay].size}"
                  end
                  # Check each resource
                  iResourcesAssignment.each do |iResource, iHours|
                    # Check the resource exists
                    if (lReturnedTaskAssignmentInfo[iDay][iResource] == nil)
                      lMessages << "[#{iTask.Name}] - [#{iDay}] - Task should have resource #{iResource.Name} assigned on this day, but the algorithm returned none."
                    else
                      # Check the number of hours
                      if (lReturnedTaskAssignmentInfo[iDay][iResource] != iHours)
                        lMessages << "[#{iTask.Name}] - [#{iDay}] - Resource should have worked #{iHours} on the task during this day, but the algorithm assigned #{lReturnedTaskAssignmentInfo[iDay][iResource]} working hours"
                      end
                    end
                  end
                  # Check that there are no extra resources we should not have
                  lReturnedTaskAssignmentInfo[iDay].each do |iResource, iHours|
                    if (iResourcesAssignment[iResource] == nil)
                      lMessages << "[#{iTask.Name}] - [#{iDay}] - Resource #{iResource.Name} should not be working for this task during this day, but the algorithm assigned #{iHours} working hours to it"
                    end
                  end
                end
              end
              # Check there are no extra days
              lReturnedTaskAssignmentInfo.each do |iDay, iResourceAssignment|
                if (iExpectedTaskAssignmentInfo[iDay] == nil)
                  lMessages << "[#{iTask.Name}] - Day #{iDay} should not have working resources, but the algorithm assigned #{iResourceAssignment.size} resources on this day:"
                  iResourceAssignment.each do |iResource, iHours|
                    lMessages << "[#{iTask.Name}] - [#{iDay}] - Resource #{iResource.Name}, working #{iHours} hours whereas it should not"
                  end
                end
              end
            end
          end
        end
        # Check there are no extra tasks
        lAssignmentInfo.each do |iTask, iReturnedTaskAssignmentInfo|
          if (iExpectedResult[iTask] == nil)
            lMessages << "Task #{iTask.Name} has been returned by the algorithm whereas it should not."
          end
        end
      end
      # Display messages if any, and assert depending on the errors.
      if (lMessages.size == 0)
        assert(true)
      else
        puts ''
        puts '!!! Errors encountered:'
        puts lMessages.join("\n")
        puts ''
        puts 'Expected to have:'
        displaySimpleAssignment(iProject, iExpectedResult)
        puts 'Got:'
        lSimpleResult = {}
        lAssignmentInfo.each do |iTask, iTaskAssignmentInfo|
          if (iTaskAssignmentInfo.FinalAssignment != nil)
            lSimpleResult[iTask] = iTaskAssignmentInfo.FinalAssignment
          end
        end
        displaySimpleAssignment(iProject, lSimpleResult)
        assert(false)
      end
    end

    # Display a simple way of an assignment info
    #
    # Parameters::
    # * *iProject* (_Project_): The project
    # * *iAssignmentInfo* (<em>map<Task,AssignmentInfoPerTask_Type></em>): The assignment info
    def displaySimpleAssignment(iProject, iAssignmentInfo)
      # Create a map to sort them by name
      lTaskNamesMap = {}
      lHeaderLength = 0
      iAssignmentInfo.keys.each do |iTask|
        lStrResources = []
        iTask.ResourcesMap.each do |iResource, iHours|
          lStrResources << iResource.Name
        end
        lHeader = "#{iTask.Name} #{iTask.Priority} #{lStrResources.join(', ')}"
        lTaskNamesMap[iTask.Name] = [ iTask, lHeader ]
        # Get the maximal length also
        if (lHeader.length > lHeaderLength)
          lHeaderLength = lHeader.length
        end
      end
      lStrDays = ''
      (iProject.StartDate..iProject.EndDate).each do |iDate|
        lStrDays += iDate.mday.to_s[-1..-1]
      end
      lCalendarLegend = "#{'-' * lHeaderLength}-+-#{lStrDays}"
      puts lCalendarLegend
      lTaskNamesMap.keys.sort.each do |iTaskName|
        iTask, iHeader = lTaskNamesMap[iTaskName]
        iTaskAssignmentInfo = iAssignmentInfo[iTask]
        lStrCalendar = ''
        (iProject.StartDate..iProject.EndDate).each do |iDate|
          if (iTaskAssignmentInfo[iDate] != nil)
            lStrCalendar += '='
          else
            lStrCalendar += ' '
          end
        end
        # Remove trailing spaces
        lStrCalendar.rstrip!
        lStrSuccessors = []
        iTask.Successors.each do |iSuccessor|
          lStrSuccessors << iSuccessor.Name
        end
        if (lStrSuccessors.length > 0)
          puts "#{iHeader.rjust(lHeaderLength)} | #{lStrCalendar}>#{lStrSuccessors.join(', ')}"
        else
          puts "#{iHeader.rjust(lHeaderLength)} | #{lStrCalendar}"
        end
      end
      puts lCalendarLegend
    end

    # Execute a simple test data, covering the majority of regression cases
    #
    # Parameters::
    # * *iSimpleTestData* (<em>list< [String,String,Integer,Integer,list<String>,String] ></em>): The data: a list of tuples [ Task name, Resource name, Priority, Sizing, Successors' names list, Final assignment string ]
    def executeSimpleTest(iSimpleTestData)
      lMaxDays = 10
      lFirstDay = Date.new(2000, 1, 1)
      # Create a standard calendar (lMaxDays days, 1 hour per day) for each resource
      # It will be populated lated
      # map< Date, Integer >
      lCalendar = {}
      # Create the index of resources
      # map< String, Resource >
      lResourcesMap = {}
      # Create the index of tasks
      # map< String, Task >
      lTasksMap = {}
      # Create the final assignment
      # map< Task, map< Date, map< Resource, Integer > > >
      lFinalAssignment = {}
      iSimpleTestData.each do |iSimpleTaskInfo|
        lTaskName, lResourceName, lPriority, lSizing, lSuccessorNamesList, lStrFinalAssignment = iSimpleTaskInfo
        if (lStrFinalAssignment.size > lMaxDays)
          lMaxDays = lStrFinalAssignment.size
        end
        # Do we already know this resource ?
        if (!lResourcesMap.has_key?(lResourceName))
          # Create the resource
          lResource = Resource.new(lResourceName, lCalendar)
          lResourcesMap[lResourceName] = lResource
        else
          lResource = lResourcesMap[lResourceName]
        end
        lTask = Task.new(lTaskName, lPriority, lSizing, {lResource => lSizing}, [])
        lTasksMap[lTaskName] = lTask
        # Set its final assignment info
        lFinalTaskAssignment = {}
        lIdxDay = 0
        lStrFinalAssignment.each_byte do |iChar|
          if (iChar == 61) # 61 == '='
            lFinalTaskAssignment[lFirstDay + lIdxDay] = {lResource => 1}
          end
          lIdxDay += 1
        end
        lFinalAssignment[lTask] = lFinalTaskAssignment
      end
      # Create the list of tasks
      # list< Task >
      lTasksList = []
      # Now populate the successors
      iSimpleTestData.each do |iSimpleTaskInfo|
        lTaskName, lResourceName, lPriority, lSizing, lSuccessorNamesList, lStrFinalAssignment = iSimpleTaskInfo
        # Retrieve the task
        lTask = lTasksMap[lTaskName]
        # Parse each successor
        lSuccessorsList = []
        lSuccessorNamesList.each do |iSuccessorName|
          # Retrieve the successor, and add it
          lSuccessorsList << lTasksMap[iSuccessorName]
        end
        # Set the successors in the real task
        lTask.Successors = lSuccessorsList
        # Add the task to the list
        lTasksList << lTask
      end
      # Create a standard project (lMaxDays days, starting from january 1st 2000)
      lProject = Project.new(lFirstDay, lFirstDay + lMaxDays)
      # Populate the calendar of each resource
      lMaxDays.times do |iIdx|
        lCalendar[lFirstDay + iIdx] = 1
      end
      # Execute the test
      executeTest(lTasksList, lProject, lFinalAssignment)
    end
    
    # Initialization before test cases
    def setup
      # Create a standard project (30 days)
      @Project1 = Project.new(Date.new(2000, 1, 1), Date.new(2000, 1, 10))
      # Create a standard calendar (30 days, 1 hour per day)
      @Calendar1 = {}
      10.times do |iIdx|
        @Calendar1[Date.new(2000, 1, iIdx+1)] = 1
      end
      # Create standard resources
      @Resource1 = Resource.new('R1', @Calendar1)
    end
    
    # ########################################################################
    # Regression usecases start from here
    # ########################################################################
    
    # Empty project
    def testEmptyProject
      # Level everything
      lResult = ProjectLeveling::levelProject([], @Project1)
      assert_equal([{}, nil], lResult)
    end

    # Single task
    def testSingleTask
      executeSimpleTest(
        [ [ 'T1', 'R1', 100, 2, [], '=='] ] )
    end

    # Basic priority
    def testBasicPriority
      # Create 2 tasks of different priorities to the same resource
      executeSimpleTest(
        [ [ 'T1', 'R1', 100, 2, [], '  =='],
          [ 'T2', 'R1', 200, 2, [], '=='] ] )
    end

    # Single task with successor of greater priority
    def testSingleSuccessorGreaterPriority
      # Create 2 tasks of different priorities to 2 resources, 1 successor of the other
      executeSimpleTest(
        [ [ 'T1', 'R1', 200, 2, [],     '  =='],
          [ 'T2', 'R2', 100, 2, ['T1'], '=='] ] )
    end
    
    # Single task with successor of smaller priority
    def testSingleSuccessorSmallerPriority
      # Create 2 tasks of different priorities to 2 resources, 1 successor of the other
      executeSimpleTest(
        [ [ 'T1', 'R1', 100, 2, [],     '  =='],
          [ 'T2', 'R2', 200, 2, ['T1'], '=='] ] )
    end

    # Use importance by looking to direct successors' priority, and not only our own priority
    def testUseImportance
      executeSimpleTest(
        [ [ 'T1', 'R1', 100, 2, ['T2'], '=='],
          [ 'T2', 'R2', 300, 2, [],     '  =='],
          [ 'T3', 'R1', 200, 2, [],     '  =='] ] )
    end
    
    # Case with a tasks reordering
    def testSimpleTasksReordering
      executeSimpleTest(
        [ [ 'T1', 'R1', 800, 2, [],     '  =='],
          [ 'T2', 'R1', 100, 2, ['T3'], '=='],
          [ 'T3', 'R2', 900, 2, [],     '   =='],
          [ 'T4', 'R3', 200, 3, ['T3'], '==='] ] )
    end
    
    # Case with a split task
    def testSplitTask
      executeSimpleTest(
        [ [ 'T1', 'R1', 500, 1, ['T2'], '='],
          [ 'T2', 'R2', 900, 2, [],     ' =='],
          [ 'T3', 'R2', 100, 4, [],     '=  ==='] ] )
    end
    
    # Case with a tasks reordering implying moving a predecessor
    # Depends on testSplitInterchangeableDay
    def testTasksReorderingWithPredecessor
      # TODO: Code the interchangeable days feature, and uncomment after
#      executeSimpleTest(
#        [ [ 'T1', 'R1', 800, 4, [],     '===  ='],
#          [ 'T2', 'R2', 100, 2, ['T3'], '=='],
#          [ 'T3', 'R1', 500, 2, ['T4'], '   =='],
#          [ 'T4', 'R3', 900, 2, [],     '     =='],
#          [ 'T5', 'R4', 200, 5, ['T4'], '====='] ] )
      executeSimpleTest(
        [ [ 'T1', 'R1', 800, 4, [],     '==  =='],
          [ 'T2', 'R2', 100, 2, ['T3'], '=='],
          [ 'T3', 'R1', 500, 2, ['T4'], '  =='],
          [ 'T4', 'R3', 900, 2, [],     '     =='],
          [ 'T5', 'R4', 200, 5, ['T4'], '====='] ] )
    end
    
    # Case with a tasks' split needed because 1 day is interchangeable between 2 tasks
    def testSplitInterchangeableDay
      # TODO: Code the interchangeable days feature, and uncomment after
#      executeSimpleTest(
#        [ [ 'T1', 'R1', 300, 2, [],     '=  ='],
#          [ 'T2', 'R1', 200, 2, ['T3'], ' =='],
#          [ 'T3', 'R2', 400, 2, [],     '   =='],
#          [ 'T4', 'R3', 100, 3, ['T3'], '==='] ] )
      executeSimpleTest(
        [ [ 'T1', 'R1', 300, 2, [],     '  =='],
          [ 'T2', 'R1', 200, 2, ['T3'], '=='],
          [ 'T3', 'R2', 400, 2, [],     '   =='],
          [ 'T4', 'R3', 100, 3, ['T3'], '==='] ] )
    end
    
    # Case with a tasks' split needed because 1 day is interchangeable between 2 tasks
    # Depends on testSplitInterchangeableDay
    def testSplitInterchangeableDayWithPriority
      # TODO: Code the interchangeable days feature, and uncomment after
#      executeSimpleTest(
#        [ [ 'T1', 'R1', 300, 2, [],     '    =='],
#          [ 'T2', 'R1', 200, 2, ['T3'], '=  ='],
#          [ 'T3', 'R2', 400, 2, [],     '    =='],
#          [ 'T4', 'R3', 100, 3, ['T3'], '==='],
#          [ 'T5', 'R1', 50,  2, ['T6'], ' =='],
#          [ 'T6', 'R4', 500, 2, [],     '   =='],
#          [ 'T7', 'R5', 30,  3, ['T6'], '==='] ] )
      executeSimpleTest(
        [ [ 'T1', 'R1', 300, 2, [],     '    =='],
          [ 'T2', 'R1', 200, 2, ['T3'], '  =='],
          [ 'T3', 'R2', 400, 2, [],     '    =='],
          [ 'T4', 'R3', 100, 3, ['T3'], '==='],
          [ 'T5', 'R1', 50,  2, ['T6'], '=='],
          [ 'T6', 'R4', 500, 2, [],     '   =='],
          [ 'T7', 'R5', 30,  3, ['T6'], '==='] ] )
    end
    
    # Case with an ordering that has to be undone after
    def testCycleReordering
      executeSimpleTest(
        [ [ 'T1', 'R2', 500,  2, ['T2'], '=='],
          [ 'T2', 'R1', 1100, 2, [],     '     =='],
          [ 'T3', 'R1', 100,  5, ['T2'], '====='],
          [ 'T4', 'R4', 200,  1, ['T5'], '='],
          [ 'T5', 'R2', 600,  2, [],     '      =='],
          [ 'T6', 'R2', 800,  4, ['T7'], '  ===='],
          [ 'T7', 'R3', 1000, 2, [],     '      =='] ] )
    end
    
    # Case with a cycle ordering that has to consider not only direct shifted importance, but also importance of successors
    def testCycleReorderingFineImportance
      executeSimpleTest(
        [ [ 'T1', 'R1', 100,  3, ['T6'],       '==='],
          [ 'T2', 'R2', 200,  2, ['T3', 'T6'], '=='],
          [ 'T3', 'R3', 800,  1, [],           '  ='],
          [ 'T4', 'R2', 300,  2, ['T5', 'T6'], '  =='],
          [ 'T5', 'R4', 700,  1, [],           '    ='],
          [ 'T6', 'R5', 1000, 2, [],           '    =='] ] )
    end
    
    # Case with a cycle ordering that has to consider not only direct shifted importance, but also importance of successors not part of the biggest importance shift, but still has to undo it due to an interchangeable day
    # Depends on testSplitInterchangeableDay
    def testCycleReorderingFineSmallerImportanceInterchangeableDay
      # TODO: Code the interchangeable days feature, and uncomment after
#      executeSimpleTest(
#        [ [ 'T1', 'R1', 100,  3, ['T8'],       '==='],
#          [ 'T2', 'R2', 200,  2, ['T3', 'T8'], ' =='],
#          [ 'T3', 'R3', 800,  1, [],           '   ='],
#          [ 'T4', 'R6', 50,   3, ['T3'],       '==='],
#          [ 'T5', 'R2', 300,  2, ['T6', 'T8'], '=  ='],
#          [ 'T6', 'R4', 700,  1, [],           '    ='],
#          [ 'T7', 'R7', 60,   3, ['T6'],       '==='],
#          [ 'T8', 'R5', 1000, 2, [],           '    =='] ] )
      executeSimpleTest(
        [ [ 'T1', 'R1', 100,  3, ['T8'],       '==='],
          [ 'T2', 'R2', 200,  2, ['T3', 'T8'], '=='],
          [ 'T3', 'R3', 800,  1, [],           '   ='],
          [ 'T4', 'R6', 50,   3, ['T3'],       '==='],
          [ 'T5', 'R2', 300,  2, ['T6', 'T8'], '  =='],
          [ 'T6', 'R4', 700,  1, [],           '    ='],
          [ 'T7', 'R7', 60,   3, ['T6'],       '==='],
          [ 'T8', 'R5', 1000, 2, [],           '    =='] ] )
    end
    
    # Case with a task reordering occuring with a task whose start date is between the shifting task's start and end dates
    def testSwitchTaskBetweenStartAndEndDates
      executeSimpleTest(
        [ [ 'T1', 'R1', 200,  3, ['T4'], '==='],
          [ 'T2', 'R2', 300,  1, ['T3'], '='],
          [ 'T3', 'R1', 500,  2, [],     '   =='],
          [ 'T4', 'R3', 1000, 2, [],     '    =='],
          [ 'T5', 'R4', 100,  4, ['T4'], '===='] ] )
    end
    
    # Case with several tasks reordering
    def testReorderingChain
      executeSimpleTest(
        [ [ 'T1', 'R2', 500, 2, ['T2'], '  =='],
          [ 'T2', 'R1', 600, 2, ['T3'], '    =='],
          [ 'T3', 'R1', 900, 2, [],     '      =='],
          [ 'T4', 'R3', 100, 3, ['T2'], '==='],
          [ 'T5', 'R4', 200, 6, ['T3'], '======'],
          [ 'T6', 'R2', 550, 2, [],     '    =='],
          [ 'T7', 'R2', 700, 2, [],     '=='] ] )
    end
    
    # Case with reordering a chain implying 2 different resources partition
    def testReorderingChainCrossPartition
      executeSimpleTest(
        [ [ 'T1', 'R2', 500,  2, ['T2'], '    =='],
          [ 'T2', 'R1', 900,  2, [],     '      =='],
          [ 'T3', 'R1', 100,  4, ['T2'], '===='],
          [ 'T4', 'R2', 800,  3, [],     '      ==='],
          [ 'T5', 'R2', 200,  4, ['T6'], '===='],
          [ 'T6', 'R3', 1000, 2, [],     '    =='] ] )
    end
    
    # Case with a cycle reordering chain implying 3 different resources partition
    def testCycleReorderingCrossPartition
      executeSimpleTest(
        [ [ 'T1', 'R2', 500,  2, ['T2'], '   =='],
          [ 'T2', 'R1', 900,  2, [],     '     =='],
          [ 'T3', 'R1', 100,  4, ['T2'], '===='],
          [ 'T4', 'R2', 800,  3, ['T5'], '==='],
          [ 'T5', 'R3', 1000, 2, [],     '    =='],
          [ 'T6', 'R3', 200,  4, ['T5'], '===='],
          [ 'T7', 'R2', 850,  3, [],     '     ==='] ] )
    end
    
    # Case with a cycle reordering chain implying 3 different resources partition all having the same predecessor
    def testCycleReorderingCrossPartitionCommonPredecessor
      executeSimpleTest(
        [ [ 'T0', 'R3', 400,  2, ['T1', 'T3', 'T4', 'T6', 'T7'], '=='],
          [ 'T1', 'R2', 500,  2, ['T2'],                         '     =='],
          [ 'T2', 'R1', 900,  2, [],                             '       =='],
          [ 'T3', 'R1', 100,  4, ['T2'],                         '  ===='],
          [ 'T4', 'R2', 800,  3, ['T5'],                         '  ==='],
          [ 'T5', 'R3', 1000, 2, [],                             '      =='],
          [ 'T6', 'R3', 200,  4, ['T5'],                         '  ===='],
          [ 'T7', 'R2', 850,  3, [],                             '       ==='] ] )
    end
    
    # Case with a single resource ordering by importance
    def testSingleResourceImportanceChain
      executeSimpleTest(
        [ [ 'T1', 'R1', 100,  2, ['T2'], '          =='],
          [ 'T2', 'R1', 900,  2, [],     '            =='],
          [ 'T3', 'R1', 300,  6, ['T2'], '    ======'],
          [ 'T4', 'R1', 200,  2, [],     '                =='],
          [ 'T5', 'R1', 800,  2, [],     '              =='],
          [ 'T6', 'R1', 950,  2, [],     '  =='],
          [ 'T7', 'R1', 1500, 2, [],     '=='] ] )
    end
    
    # Case with a task shifted by another one, far successor of a neighbour
    def testTaskShiftedByFarSuccessor
      executeSimpleTest(
        [ [ 'T1', 'R2', 800,  2, ['T2'], '  =='],
          [ 'T2', 'R1', 1000, 2, [],     '    =='],
          [ 'T3', 'R1', 200,  4, ['T2'], '===='],
          [ 'T4', 'R2', 900,  2, ['T5'], '=='],
          [ 'T5', 'R1', 850,  2, [],     '      =='] ] )
    end
    
    # Case with a chain of successors shifted up to a certain point
    def testShiftSuccessorsChain
      executeSimpleTest(
        [ [ 'T1', 'R1', 500, 2, ['T2'], '=='],
          [ 'T2', 'R2', 150, 2, ['T4'], '   =='],
          [ 'T3', 'R2', 100, 3, ['T2'], '==='],
          [ 'T4', 'R3', 900, 2, [],     '      =='],
          [ 'T5', 'R3', 120, 6, ['T4'], '======'],
          [ 'T6', 'R1', 800, 3, [],     '  ==='] ] )
    end
    
    # Case with 2 resource partitions, when 1 is reordered, it changes forcefully the other one due to successors
    def testReorderingChangingCrossPartition
      executeSimpleTest(
        [ [ 'T1', 'R1', 900,  5, ['T2'], '====  ='],
          [ 'T2', 'R2', 800,  2, [],     '       =='],
          [ 'T3', 'R2', 700,  2, ['T4'], '  =='],
          [ 'T4', 'R1', 600,  2, ['T5'], '    =='],
          [ 'T5', 'R3', 1000, 2, [],     '      =='],
          [ 'T6', 'R4', 100,  5, ['T5'], '====='],
          [ 'T7', 'R2', 200,  2, ['T8'], '=='],
          [ 'T8', 'R5', 2000, 2, [],     '   =='],
          [ 'T9', 'R6', 300,  3, ['T8'], '==='] ] )
    end
    
    # Case with 2 resource partitions (A and B):
    # * A is reordered according to its resources
    # * B is in conflict due to further successors (far after first A's reordering), and the only solution is to redorder back A
    def testInvalidateReorderingDueToFurtherDifferentPartitionConflict
      executeSimpleTest(
        [ [ 'T01', 'RA1', 200, 2, ['T02'], '=='],
          [ 'T02', 'RB2', 500, 2, ['T04'], '   =='],
          [ 'T03', 'R03', 10,  3, ['T02'], '==='],
          [ 'T04', 'R04', 800, 2, [],      '       =='],
          [ 'T05', 'R05', 20,  7, ['T04'], '======='],
          [ 'T06', 'RA1', 100, 2, ['T07'], '  =='],
          [ 'T07', 'R06', 600, 2, [],      '    =='],
          [ 'T08', 'R07', 30,  3, ['T07'], '==='],
          [ 'T09', 'R08', 40,  4, ['T10'], '===='],
          [ 'T10', 'RB2', 50,  2, ['T11'], '     =='],
          [ 'T11', 'R09', 700, 2, [],      '       =='],
          [ 'T12', 'R10', 60,  7, ['T11'], '======='] ] )
    end
    
    # Case testing 2 cycles while reordering in the same partition. This forces the algorithm to force 2 times already tried paths that were not optimal. The 2 paths forced are not related (the second is not among the sub-tree of the first one).
    def test2CycleReorderingSamePartition
      executeSimpleTest(
        [ [ 'T1', 'R1', 500,  2, ['T2'], '  =='],
          [ 'T2', 'R2', 600,  2, ['T3'], '    =='],
          [ 'T3', 'R3', 900,  2, [],     '      =='],
          [ 'T4', 'R4', 100,  3, ['T2'], '==='],
          [ 'T5', 'R5', 200,  6, ['T3'], '======'],
          [ 'T6', 'R1', 550,  2, ['T7'], '=='],
          [ 'T7', 'R6', 1000, 2, [],     '     =='],
          [ 'T8', 'R7', 300,  5, ['T7'], '====='],
          [ 'T9', 'R1', 700,  2, [],     '    =='] ] )
    end
    
    # Case that takes into account interchangeable days will modify the importances computed to build the already tried paths.
    # This mixes the 2 changes: InterchangeableDay and InvalidatedAlreadyTriedPaths.
    # Depends on testSplitInterchangeableDay
    # Depends on testInvalidatedAlreadyTriedPathsDueToResourcesConflict
    def testInterchangeableDayInvalidatesAlreadyTriedPaths
      # TODO: Code the interchangeable days and already tried paths invalidated feature, and uncomment after
#      executeSimpleTest(
#        [ [ 'T1', 'R1', 100,  2, ['T2'],       '  =='],
#          [ 'T2', 'R3', 500,  2, [],           '    =='],
#          [ 'T3', 'R1', 200,  2, ['T4', 'T5'], '=='],
#          [ 'T4', 'R4', 300,  2, [],           '  =='],
#          [ 'T5', 'R2', 600,  2, [],           '  =   ='],
#          [ 'T6', 'R2', 50,   5, ['T7'],       '== ==='],
#          [ 'T7', 'R5', 1000, 2, [],           '      =='],
#          [ 'T8', 'R6', 400,  6, ['T7'],       '======'] ] )
      # TODO: Code the already tried paths invalidated feature (without having interchangeable days feature), and uncomment after
#      executeSimpleTest(
#        [ [ 'T1', 'R1', 100,  2, ['T2'],       '=='],
#          [ 'T2', 'R3', 500,  2, [],           '  =='],
#          [ 'T3', 'R1', 200,  2, ['T4', 'T5'], '  =='],
#          [ 'T4', 'R4', 300,  2, [],           '    =='],
#          [ 'T5', 'R2', 600,  2, [],           '     =='],
#          [ 'T6', 'R2', 50,   5, ['T7'],       '====='],
#          [ 'T7', 'R5', 1000, 2, [],           '      =='],
#          [ 'T8', 'R6', 400,  6, ['T7'],       '======'] ] )
      executeSimpleTest(
        [ [ 'T1', 'R1', 100,  2, ['T2'],       '  =='],
          [ 'T2', 'R3', 500,  2, [],           '    =='],
          [ 'T3', 'R1', 200,  2, ['T4', 'T5'], '=='],
          [ 'T4', 'R4', 300,  2, [],           '  =='],
          [ 'T5', 'R2', 600,  2, [],           '     =='],
          [ 'T6', 'R2', 50,   5, ['T7'],       '====='],
          [ 'T7', 'R5', 1000, 2, [],           '      =='],
          [ 'T8', 'R6', 400,  6, ['T7'],       '======'] ] )
    end
    
    # Case that tests the already tried paths tree invalidated due to a further successors' shift, that changes importances used for the paths' tree.
    def testInvalidatedAlreadyTriedPathsDueToDependencies
      # TODO: Code the already tried paths invalidated feature, and uncomment after
#      executeSimpleTest(
#        [ [ 'T1', 'R3', 10,  3, ['T2'],       '==='],
#          [ 'T2', 'R4', 500, 2, [],           '    =='],
#          [ 'T3', 'R1', 600, 2, ['T2'],       '=='],
#          [ 'T4', 'R1', 400, 2, ['T2', 'T7'], '  =='],
#          [ 'T5', 'R2', 300, 2, ['T2', 'T7'], '=='],
#          [ 'T6', 'R2', 200, 2, ['T7'],       '  =='],
#          [ 'T7', 'R5', 700, 2, [],           '    =='],
#          [ 'T8', 'R6', 20,  3, ['T7'],       '==='] ] )
      executeSimpleTest(
        [ [ 'T1', 'R3', 10,  3, ['T2'],       '==='],
          [ 'T2', 'R4', 500, 2, [],           '    =='],
          [ 'T3', 'R1', 600, 2, ['T2'],       '  =='],
          [ 'T4', 'R1', 400, 2, ['T2', 'T7'], '=='],
          [ 'T5', 'R2', 300, 2, ['T2', 'T7'], '=='],
          [ 'T6', 'R2', 200, 2, ['T7'],       '  =='],
          [ 'T7', 'R5', 700, 2, [],           '    =='],
          [ 'T8', 'R6', 20,  3, ['T7'],       '==='] ] )
    end
    
    # Case that tests the already tried paths tree invalidated due to a further resources' conflict, that changes importances used for the paths' tree.
    def testInvalidatedAlreadyTriedPathsDueToResourcesConflict
      # TODO: Code the already tried paths invalidated feature, and uncomment after
#      executeSimpleTest(
#        [ [ 'T1', 'R3', 10,   3, ['T2'],       '==='],
#          [ 'T2', 'R4', 450,  2, [],           '    =='],
#          [ 'T3', 'R1', 400,  2, ['T2', 'T4'], '  =='],
#          [ 'T4', 'R2', 1000, 2, [],           '    =='],
#          [ 'T5', 'R5', 20,   3, ['T4'],       '==='],
#          [ 'T6', 'R1', 500,  2, [],           '=='],
#          [ 'T7', 'R2', 30,   4, ['T8'],       '===='],
#          [ 'T8', 'R6', 1100, 2, [],           '     =='],
#          [ 'T9', 'R7', 40,   5, ['T8'],       '====='] ] )
      executeSimpleTest(
        [ [ 'T1', 'R3', 10,   3, ['T2'],       '==='],
          [ 'T2', 'R4', 450,  2, [],           '   =='],
          [ 'T3', 'R1', 400,  2, ['T2', 'T4'], '=='],
          [ 'T4', 'R2', 1000, 2, [],           '    =='],
          [ 'T5', 'R5', 20,   3, ['T4'],       '==='],
          [ 'T6', 'R1', 500,  2, [],           '  =='],
          [ 'T7', 'R2', 30,   4, ['T8'],       '===='],
          [ 'T8', 'R6', 1100, 2, [],           '     =='],
          [ 'T9', 'R7', 40,   5, ['T8'],       '====='] ] )
    end
    
    # TODO: Regression testing the choice between several possible resources

  end
  
end
