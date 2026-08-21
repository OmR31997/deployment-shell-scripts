======================================
      EC2 MEMORY ALARM SETUP
======================================

Instance ID: i-0123456789abcdef

Enter memory utilization limit (%) [e.g. 80]: 80

When memory reaches 80%, what should happen?

1) REBOOT EC2
2) STOP EC2
3) DO NOTHING

Select option [1-3]: 1

--------------------------------------
Configuration
--------------------------------------
Instance : i-0123456789abcdef
Limit    : 80%
Action   : REBOOT
--------------------------------------

Continue? (y/n): y

✓ CloudWatch Agent installed
✓ Memory monitoring configuration created
✓ CloudWatch Agent started

Creating / updating CloudWatch alarm...

======================================
          SETUP COMPLETED
======================================