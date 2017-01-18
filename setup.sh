#!/bin/bash
./bin/slice add slice_a
./bin/slice add_host --mac 54:53:ed:1c:36:82 --port 0x8:23 --slice slice_a
./bin/slice add_host --mac 08:00:27:61:62:98 --port 0x1:1 --slice slice_a
