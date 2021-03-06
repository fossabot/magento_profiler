<?php

class Ecocode_Profiler_Tests_Dev_Model_Collector_EventDataCollectorTest
    extends TestHelper
{

    public function testCollect()
    {
        $collector = new Ecocode_Profiler_Model_Collector_EventDataCollector();

        $collector->collect(
            new Mage_Core_Controller_Request_Http(),
            new Mage_Core_Controller_Response_Http()
        );


        $this->assertCount(0, $collector->getCalledListeners());
        $this->assertCount(0, $collector->getFiredEvents());
    }

    public function testLateCollect()
    {
        $collector = $this->getMockedCollector();

        $app = new Ecocode_Profiler_Model_AppDev();
        $app->init('admin', 'store');
        $collector->method('getApp')
            ->willReturn($app);

        $preDispatchData = json_decode('{"observers":{"log":{"type":"","model":"log\/visitor","method":"initByRequest","args":[]},"pagecache":{"type":"","model":"pagecache\/observer","method":"processPreDispatch","args":[]}}}', true);
        $events          = ['global' => ['controller_action_predispatch' => $preDispatchData]];
        $calledListeners = [
            ['event_name' => 'non-existing'],
            ['event_name'     => 'controller_action_predispatch',
             'class'          => 'TEST_CLASS',
             'method'         => 'xxx',
             'execution_time' => 10]
        ];

        $app->dispatchEvent('resource_get_tablename', []);
        $app->dispatchEvent('controller_action_predispatch', []);
        $app->dispatchEvent('controller_action_predispatch', []);

        $this->setProtectedValue($app, '_events', $events);
        $this->setProtectedValue($app, 'calledListeners', $calledListeners);


        $collector->lateCollect();

        $firedEvents = $collector->getFiredEvents();
        $this->assertCount(2, $collector->getCalledListeners());
        $this->assertCount(2, $collector->getFiredEvents());
        $this->assertEquals(10, $collector->getTotalTime());

        $data = $firedEvents['controller_action_predispatch'];
        $this->assertEquals(2, $data['count']);
        $this->assertEquals(2, $data['observer_count']);
        $this->assertCount(1, $data['observer']);
        $this->assertCount(2, $data['observer']['global']);

    }

    /**
     * @return Ecocode_Profiler_Model_Collector_EventDataCollector
     */
    public function getMockedCollector()
    {
        $collectorMock = $this->getMockBuilder('Ecocode_Profiler_Model_Collector_EventDataCollector')
            ->setMethods(['getApp'])
            ->getMock();


        return $collectorMock;
    }
}
