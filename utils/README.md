Here is how to use this code

```

# create venv using system Python 3
python3 -m venv .venv

# activate it (zsh / bash)
source .venv/bin/activate

# upgrade pip and show python version
python -m pip install --upgrade pip
python --version
```

Install the required packages

```
# minimal
pip install numpy scipy

# if you want the demo table display used earlier
pip install pandas

# (optional) Matplotlib if you plan to plot
pip install matplotlib
```

Test it with

```
python test_run.py
```




