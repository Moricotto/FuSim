import pandas as pd
import matplotlib.pyplot as plt

# Read the CSV file into a pandas DataFrame
data = pd.read_csv('data/scatter0.csv')

# Create a pivot table to reshape the data
pivot_table = data.pivot(index='row_label', columns='column_label', values='value')

# Create a heatmap using matplotlib
plt.imshow(pivot_table, cmap='hot', interpolation='nearest')

# Add colorbar
plt.colorbar()

# Set labels and title
plt.xlabel('X Label')
plt.ylabel('Y Label')
plt.title('2D Heatmap')

# Show the plot
plt.show()