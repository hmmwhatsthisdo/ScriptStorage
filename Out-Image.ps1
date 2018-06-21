Function Out-Image {
Param(

    [Parameter(
        Mandatory = $true,
        Position = 0,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [ValidateNotNullOrEmpty()]
    [System.Drawing.Image]$Image,

    [Parameter(
        Position = 1
    )]
    [String]$Title = "Image Viewer"


)

Begin {

}

Process {
    
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

    $Form = [System.Windows.Forms.Form]::new()

    $Form.Text = $Title
    $Form.Height = $Image.Size.Height
    $Form.Width = $Image.Size.Width
    
    $PictureBox = [System.Windows.Forms.PictureBox]::new()
    $PictureBox.Height = $Image.Size.Height
    $PictureBox.Width = $Image.Size.Width
    $PictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::CenterImage
    
    $PictureBox.Image = $Image

    $Form.Controls.Add($PictureBox)

    $Form.Add_Shown( { $Form.Activate() } )
    
	$Form.ShowDialog() | Out-Null

}

}