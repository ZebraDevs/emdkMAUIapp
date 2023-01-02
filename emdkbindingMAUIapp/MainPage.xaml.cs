using Microsoft.Maui.Controls.Compatibility;
using Microsoft.Maui.Controls;
using CommunityToolkit.Mvvm.Messaging;

namespace emdkMAUIapp;

public partial class MainPage : ContentPage
{
	int count = 0;

	public MainPage()
	{
		InitializeComponent();

        WeakReferenceMessenger.Default.Register<string>(this, (r, m) =>
        {
            MainThread.BeginInvokeOnMainThread( () => { lbWelcome.Text = m;} );
        });

    }


	private void OnCounterClicked(object sender, EventArgs e)
	{
		count++;

		if (count == 1)
			CounterBtn.Text = $"Clicked {count} time";
		else
			CounterBtn.Text = $"Clicked {count} times";

		SemanticScreenReader.Announce(CounterBtn.Text);

        WeakReferenceMessenger.Default.Send("HI_ANDROID");

    }
}

