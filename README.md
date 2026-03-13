﻿# Reddits visualization
Visualizations for reddits data with application of **Power BI** dashboards. **Looker** dashboards will come soon.

**IMPORTANT**: Before launching the Power BI dashboards, it is necessary to download the Venn diagram visualization from [GitHub source](https://github.com/DataChant/PowerBI-Visuals-AppSource/blob/main/All%20Visuals/PBIVIZ%20with%20versions/vennDiagram8527AJ74DB74562488PCR752UTY9465.4.0.0.0.pbiviz) and import it into the dashboard.
 
 ## Concepts glossary
 1. **Reddit** -- a social medium platform Reddit.com as well as the specific name of Reddits posts
 2. **Comment** -- a comment of a *reddit*
 3. **Reply n-th level** -- a reply of a reddits *comment*. A level of reply denotes how deeply the reply lays. Reply 1-st level denotes a reply of a *comment*, reply 2-nd level denotes a reply of a reply of a *comment*, as so on and so forth
 4. **Author** -- an author of a *reddit*, a *comment* or a *reply*
 5. **Phrase** -- a word or a words sequence referring to a group of *reddits* to analyse, i.e. to show to analyses results for different reddit topics. In the project the *reddits* are analysed in 6 different phrases: *aussie*, *border collie*, *corgi*, *iran*, *israel* and *trump*.
 6. **Entry type** -- a type of an entry on Reddit platform. A *reddit* or a *comment*
 7. **Entry category** -- a category of an analysed element. A *reddit*, a *comment* or a *reply* of various level
 8. **Sentiment** --  a measure of an *entry* text of certain *author* denoting his attitude, thought or judgement prompted by feeling. The sentiment may be **negative** (how much the entry text is negative), **neutral** (how neutral), **positive** (how positive) and **compound** (overall measure). The **polarity** sentiment denotes the coefficient how negative/posititve the texts is and **subjectivity**, its subjectiveness
 9. **Sentiment category** -- category of *entry* text *sentiment* from: "negative", "neutral" and "positive". The texts *sentiment* is negative when its compound measure is greater than or equal to -1 and less than -0.33, positive when larger than 0.33 and less than or equal to 1 and neutral if between -0.33 and 0.33
 10. **Popularity** -- a measure of an *entry* denoting how popular the *entry* is on Reddit platform. A **number of reddits** (per day) **number of comments**, **reactions**, **upvote ratio** (fraction of number of up reactions and all reactions) or **number of controversial entries** are the examples of such measures. 
 
 ## Dataflow diagram
![reddits_sentiment_timeline_counts](/assets/images/reddits_sentiment_timeline_counts.png)
1. Importing the data from *Supabase Postgres* tables or via *SQL statement*.
2. Data transformation via *Power BI/Looker* data transformation tools.
3. Visualization of transformed data on *Power BI/Looker* dashboards.

 ## Dashboards list
1. SentimentAnalysis.pbix -- 2 dashboards: 
    * **"Reddits -- sentiment timeline & counts distribution"**
    * **"Authors -- sentiment histograms & categories distribution"**
2. PopularityAnalysis.pbix -- 3 dashboards:
    * **"Reddits -- popularity timeline & counts distribution"**
    * **"Reddits -- entry level histograms"**
    * **"Authors -- popularity measure histograms"** 

## Dashboards
### Reddits -- sentiment timeline & counts distribution
![reddits_dataflow_visual](/assets/images/reddits_dataflow_visual.png)
**Question**: *How do the sentiment values change on the timeline and what is the sentiment categories overall distribution?*

**Components**:
1. **Phrase and entry type selectors.** *[top left]* To differ the analyses for each phrase and entry type. 
2. **Sentiment category counts wheel chart.** *[bottom left]* To display the entry counts distribution according to: negative, neutral and positive sentiments.
3. **Median sentiment values timeline.** *[top right]* To visualize how the median date aggregated (negative, neutral and positive) sentiment values change over a period of time.
4. **Average polarity and subjectivity timeline.** *[bottom right]* To show the changes of texts polarity and subjectivity over a period of time.

### Authors -- sentiment histograms & categories distribution
![reddits_sentiment_histogram_counts](/assets/images/reddits_sentiment_histogram_counts.png)
**Question**: *How many authors post texts which sentiment measure has got the certain value or which sentiment category has aquired?*

**Components**:
1. **Phrase and entry type selectors.** *[top left]* To differ the analyses for each phrase and entry type. 
2. **Sentiment category counts distribution Venn diagram.** *[bottom left]* To display the author counts who posted texts which acquired sentiment of certain category. Some authors posted texts of more than two sentiment categories.
3. **6 histograms of authors number who posted texts yielding: negative, neutral, positive, compound, polarity and subjectivity sentiments.** *[middle and left]* To visualize the quantitive distribution of authors whose texts indicate sentiments of certain measure value.

### Reddits -- popularity timeline & counts distribution
![reddits_popularity_timeline_counts](/assets/images/reddits_popularity_timeline_counts.png)
**Question**: *How do the popularity values change on the timeline and what is the entries controversiality overall distribution?*

**Components**:
1. **Phrase and entry category selectors.** *[top left]* To differ the analyses for each phrase and entry category. 
2. **Controversial entries wheel chart.** *[top left]* To show how many entries overall are marked as controversial.
3. **Entry category ring chart.** *[bottom left]* To display the overall distribution of various category entries.
4. **4 timelines (date aggregated).** *[right]* To visualize how the popularity measures are changing over time period.
	4.1. Total number of comments/replies. *[top]*
	4.2. Total number of reactions. *[middle]*
	4.3. Average number of reactions per entry, i.e. fraction of reactions number and comments/replies. *[middle]*
	4.4. Minimal upvote ratio. Maximal was not visualized due to lack of significant changes in value. *[bottom]*

### Reddits -- entry level histograms
![reddits_popularity_entry_level_histogram_counts](/assets/images/reddits_popularity_entry_level_histogram_counts.png)
**Question**: *How does the texts popularity look like according to reactions number of various category (level) entries?*

**Components**:
1. **Phrase selector.** *[top left]* To differ the analyses for each phrase. 
2. **9 reaction counts histograms.** *[middle and right]* To visualize the distributions of reaction numbers for entries of 9 categories.
	2.1. Reddit category distribution. *[top left]*
	2.2. Comment category distribution. *[top center]*
	2.3. Reply 1-st level category distribution. *[top right]*
	2.4. Reply lower levels category distributions. *[middle and bottom]*

### Authors -- popularity measure histograms
![reddits_popularity_histogram_counts](/assets/images/reddits_popularity_histogram_counts.png)
**Question**: *How does the texts popularity look like according to authors number of various popularity measures and what is the authors distribution who posted texts marked as controversial or not?*

**Components**:
1. **Phrase and entry category selectors.** *[top left]* To differ the analyses for each phrase and entry category. 
2. **Authors of controversial or not controversial entries distribution Venn diagram.** *[bottom left]* To show how many authors posted texts which were marked as controversial or not. Some authors posted texts marked as controversial as well as these marked as not.
3. **4 authors number histograms.** *[center and right]* To visualize the 4 popularity measure values distribution according to number of authors.
	3.1. Total number of comments/replies. *[top left]*
	3.2. Total number of texts gildings, i.e. times the entry was awarded by Reddit platform admins. *[top right]*
	3.3. Total number of reactions. *[bottom left]*
	3.4. Minimal upvote ratio. *[bottom right]*
